# Poller在不同版本之间的差异

## 木马特点

- 由于比Filter/Listen更前置，所以能做更多的事情
- 会读取socket写通道的数据，因此需要API本身支持数据回写的功能（下面提供了能够回写socket支持的版本，但是此回写是一种假回写）
- 采用比较激进的方式将旧监听的线程都杀死，然后替换木马Poller，所有如果业务量大的情况，业务会出现明显的连接中断，但是重新刷新页面后可以继续访问，所以最好在业务量小的时候进行，尽可能避免被发现异常的行为。
- 旧版本的tomcat，由于不支持socket回写，因此在多次尝试后，发现缓存数据是唯一可靠的，但是需要注意一点，这种缓存是建立在keep-alive的机制进行（即一次通信TCP会话中），如果反向代理不支持keep-alive，将无法运行。

## 基本版本

```yaml
spring-boot-dependencies >= 1.4.0.RELEASE
tomcat-embed-core >= 8.5.0
tomcat >= 8.5.0
```



## 优化

### read函数的变化(优化一)

由于socket的数据是通过read函数读取数据的，但是tomcat各个版本中存在一些小差异如下

```yaml
tomcat >= 8.5.8
tomcat-embed-core >= 8.5.8
spring-boot-dependencies >= 1.4.4.RELEASE
```

以上数据在版本高于标准线时，read的函数签名如下

```yaml
read(boolean,java.nio.ByteBuffer) throws java.io.IOException
```

在低于标准线时，read的函数签名如下

```yaml
read(boolean,byte[],int,int) throws java.io.IOException
```



### Poller数组的问题(优化二)

旧版本的tomcat中Poller并不是一个单线程poller的形式存在，而是以数组的形式存放在pollers成员变量

```yaml
tomcat-coyote >= 8.5.76
tomcat-embed-core >= 8.5.76
spring-boot-dependencies >= 2.1.0.RELEASE

Poller已经不在是数组了，而是Poller单类
```

### Poller线程名称问题(优化三)

```yaml
在tomcat较低版本中,Poller类的线程以http-xxx-ClientPoller-xxx存在
在tomcat较高版本Poller类的线程以http-xxx-poller-xxx
```

### websocket服务中断(优化四)

```yaml
unread回写buffer的大小严格受控，如果buffer设置过大，会引起服务端主动断开连接
```