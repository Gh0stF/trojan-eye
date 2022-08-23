# Poller(Executor)内存马面对websocket的Bug

深蓝师傅利用NioEndpoint.NioSocketWrapper.unread函数解决了socket数据读取复用的问题，但是其实unread函数的ByteBuffer，如果大小如果设置不当，会给业务本身带来毁灭性的打击。我深感这种直接HOOK到socket层面的内存马带来的巨大影响，所以还是代师傅探索一些未知的问题，所以我自行测试了不少流量，最终还是被我发现了一个未知BUG。

## 旧实现存在的严重BUG

我先把旧实现关键部分贴出来

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660372260165-4a9d9ad1-6a91-481b-bfb0-ae8035fedbf0.png)

这里深蓝师傅很保守的将新的Buffer设置成和系统默认一样的大小，但是其实就是这个默认设置，导致内存马注入后，服务器将无法正常运行websocket服务。

### 测试

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660372964321-a67eeea1-1bed-4933-bd71-12a7e07957bd.png)

我在存在websocket服务的tomcat中安置好内存马，接着测试发现服务一直永远连不上，起初我以为是我本地服务的问题，但是当我把内存马关了，服务竟然通畅无阻。接着，为了确定哪块代码的错误，我把马子的代码一段一段做了测试，最终发现以下情况

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660373195874-d0a1bb2b-2e09-4379-bc33-c448b85fd7cc.png)

我把代码删到只剩数据复用这里时，服务还是无法正常通信，这把我弄慌了，不对啊，代码已经是最小了，普通的HTTP业务也能正常访问，偏偏为啥websocket就有问题了。就是我抓了包

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660373398318-0ad5c9a3-7992-4db7-8a8a-fafef5e24d91.png)

看到这里我蒙了，怎么一连接服务器就自动发起关闭了？于是开启DEBUG大法

### 原因：缓冲区的大小

最终发现问题出现在业务处理的过程，先给出调用栈

```yaml
onDataAvailable:61, WsFrameServer (org.apache.tomcat.websocket.server)
doOnDataAvailable:183, WsFrameServer (org.apache.tomcat.websocket.server)
notifyDataAvailable:162, WsFrameServer (org.apache.tomcat.websocket.server)
upgradeDispatch:157, WsHttpUpgradeHandler (org.apache.tomcat.websocket.server)
dispatch:60, UpgradeProcessorInternal (org.apache.coyote.http11.upgrade)
process:59, AbstractProcessorLight (org.apache.coyote)
process:889, AbstractProtocol$ConnectionHandler (org.apache.coyote)
doRun:1735, NioEndpoint$SocketProcessor (org.apache.tomcat.util.net)
run:49, SocketProcessorBase (org.apache.tomcat.util.net)
runWorker:1191, ThreadPoolExecutor (org.apache.tomcat.util.threads)
run:659, ThreadPoolExecutor$Worker (org.apache.tomcat.util.threads)
run:61, TaskThread$WrappingRunnable (org.apache.tomcat.util.threads)
run:745, Thread (java.lang)
```

当客户端第一次请求weboscket升级协议的时候，tomcat会响应是否支持升级。如果支持的话，会发送正确的响应的回去。此时tomcat并没有就此停止等待消息，而是会来到WsFrameServer.onDataAvailable中检查读缓冲区的数据是否异常

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660375043056-792de7f5-4d85-4a56-8d3d-a7a83241668d.png)

这里可以看到，socketWrapper就是我们最开始控制的socket，由于缓冲区设置成8192，并且我们发送的HTTP消息也才不到2000字节，这就导致可读取的数据其实就是大于0的。一旦大于0就会抛出异常，这个异常就导致服务器主动关闭连接。那么socketWrapper到底是怎么read数据的，这也让我产生兴趣了。因为服务器默认的buffer就是8192，为什么服务器默认的就行，我们一旦设置就会导致read > 0，如果真有这个影响，socket内存马可不能用了！带着这个问题，我又仔细阅读源码的处理流程。



## socketWrapper.read

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660375629766-97350f9c-dbc2-422e-b983-01af69a025c0.png)

逻辑还是比较简单的，其实就是两种方式读取数据

- this.populateReadBuffer(to);
- this.fillReadBuffer(block, to);

先看this.populateReadBuffer(to)

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660375783543-afabb803-fc05-4517-8a13-fa09f21f83fb.png)

可以看到逻辑就是把tomcat自带buffer的数据写到函数提供的buffer之中，前提是两者都必须还有可写的空间。



再看this.fillReadBuffer(block, to)

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660376038915-02f5c005-17e4-4ca4-ab5a-1deccff310ee.png)

其实fillReadBuffer就是直接从socket中读取数据。



到这里我们得出以下结论：

- socketWrapper提供的read是先读取buffer中的数据的，并且是返回buffer可写的数量
- socketWrapper只有在缓冲区没有数据的情况下，才会读socket通道的数据

经过详细的测试，我得到socketWrapper对buffer的处理：

- socketWrapper其实并没有把数据都装载到buffer中，而是直接读取socket中的数据



两者对比后可以得到结论：

- socketWrapper本身并不利用buffer做什么，所以在websocket尝试读buffer的数据时，read一定等于0
- socketWrapper经过业务处理，socket通道上的数据一定被读完了，所以read也一定等于0



## 解决Debug

既然知道愿意了，要处理就很简单了，思路如下：

1. 我们不用socketWrapper的unread，采用缓存机制
2. 我们想办法让buffer中的数据被业务读取后，立即清空buffer

对于第一种情况，不再阐述。第二种其实实现困难，因为业务一旦放行，我们已经没有控制权了，毕竟多线程的环境，做不了。既然我们的目的是清空buffer，最好的办法就是让buffer无数据可读。回过头来看一下socketWrapper的判断

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1660377024568-3fc09b5e-678b-41bf-8377-cefbb70941da.png)

可以看到，read其实就是取两个buffer可读的最小的，ByteBuffer.remaining就是获取当前buffer的可读大小（其中涉及到postion，limit，caption三个指针，推荐自行了解ByteBuffer的内部结构）。所以最佳的解决方案就是：有多少数据，ByteBuffer就设置成多大。



## 最终代码

```yaml
protected void processKey(SelectionKey sk, NioEndpoint.NioSocketWrapper attachment) {
//        推荐作为全局变量，做中间管道
        ByteBuffer allocate = ByteBuffer.allocate(8192);
        int read = 0;
        try {
            read = attachment.read(false, allocate);
        } catch (IOException e) {
        }


        ByteBuffer readBuffer = ByteBuffer.allocate(read);
//        有多少数据就设置多少数据
        readBuffer.put(allocate.array(), 0, read);
        readBuffer.position(0);
        attachment.unRead(readBuffer);
        super.processKey(sk, attachment);
}
```