# Poller内存马基本骨架

> 前言
>
> ​	Poller作为负责创建处理web业务线程的线程类，同时也是作为收到请求后，除开Acceptor接收器后，第一个直面网络请求的线程类。由于他存在的位置如此靠前，这给流量监控等技术应用带来巨大的施展舞台。但是由于最是靠前的处理线程类，所以也直面NIO网络模式常见的很多问题，如果要控制这一层面作为内存马的舞台，势必要解决很多socket网络编程中常见的问题。

以下是Poller中出现的一些bug，有兴趣可了解：

+ [解决Poller(Executor)内存马的旧版本问题](https://github.com/Kyo-w/trojan-eye/blob/master/theory/buffersocket.md)
+ [Poller在不同版本之间的差异](https://github.com/Kyo-w/trojan-eye/blob/master/theory/version.md)
+ [Poller(Executor)内存马面对websocket的Bug](https://github.com/Kyo-w/trojan-eye/blob/master/theory/websocktbug.md)

## 继承Poller+重写processKey

​	为什么要继承Poller？首先得说明白tomcat的业务处理逻辑：起初客户侧发起的网络请求第一时间会被Acceptor获知，接着Acceptor在接收到网络请求后，会把socket的连接事件通知到Poller，然后Poller会调用processKey方法，其中processKey会调用SocketProcessor执行类用于执行业务逻辑。基于这个过程，我们如果可以重写processKey方法，那么就可以控制所有的请求流。这就是Poller内存马的基本架构

​	但是比较有趣的是，Poller并不是一个普通的类，他是NioEndpoint的内部非静态类

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661224170469-873a1fe8-0254-4f39-b096-a362cd164b9d.png)

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661224177076-c9beab94-9495-437b-8653-a662ef6661c7.png)

因此，我们的构造方法必须要传入一个NioEndpoint。（推荐了解一下如何继承非静态内部类）

![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661224185959-05844e24-27d4-442a-bedb-c0c5d4b3b015.png)

就是，我们就有了第一个简单的马子

```java
/**
 * @author KyoDream
 * @2022/8/23
 */
public class TestTroJan extends NioEndpoint.Poller {
    public TestTroJan(NioEndpoint nioEndpoint) throws IOException {
        nioEndpoint.super();
    }

    @Override
    protected void processKey(SelectionKey sk, NioEndpoint.NioSocketWrapper attachment) {
//        在处理业务之前，你需要做什么
        super.processKey(sk, attachment);
//        在完成业务线程启动之后（super.processKey(sk, attachment)会启动一个线程执行业务逻辑，这是一个多线程的环境，不可理解为普通的方法调用）
    }
}

```
