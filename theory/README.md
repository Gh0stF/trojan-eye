# Poller内存马基本骨架

> 前言
>
> ​	Poller作为负责创建处理web业务线程的线程类，同时也是作为收到请求后，除开Acceptor接收器后，第一个直面网络请求的线程类。由于他存在的位置如此靠前，这给流量监控等技术应用带来巨大的施展舞台。但是由于最是靠前的处理线程类，所以也直面NIO网络模式常见的很多问题，如果要控制这一层面作为内存马的舞台，势必要解决很多socket网络编程中常见的问题。

以下是Poller中出现的一些bug，有兴趣可了解：

+ [解决Poller(Executor)内存马的旧版本问题](https://github.com/Kyo-w/trojan-eye/blob/master/theory/buffersocket.md)
+ [Poller在不同版本之间的差异](https://github.com/Kyo-w/trojan-eye/blob/master/theory/version.md)
+ [Poller(Executor)内存马面对websocket的Bug](https://github.com/Kyo-w/trojan-eye/blob/master/theory/websocktbug.md)

## 继承Poller+重写processKey

​	为什么要继承Poller？因为Acceptor在接受到网络请求后，会向
