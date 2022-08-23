# Trojan-eye![img](https://cdn.nlark.com/yuque/0/2022/svg/1599979/1661232579049-22126984-d193-4d93-82b6-c1ac6b0a37fc.svg) ![img](https://cdn.nlark.com/yuque/0/2022/svg/1599979/1661232578970-8859978f-4727-466b-ab2e-1b8657ea3ac2.svg) ![img](https://cdn.nlark.com/yuque/0/2022/svg/1599979/1661232578997-8b1a3bfd-85ee-4ac1-b144-4718aa0cb9d5.svg)

​	以Socket层面获得流量的控制权，以websocket做流量的通信，以electron做数据展示。

## 流量走向示意图![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232603563-569981c2-540a-40ba-9ef1-febf1d0972a9.png)

## 使用

1. 将trojan目录下的eyes.jsp上传并执行访问。
2. 打开trojan-eye.exe，开启监听
3. 在收集器中接收实时流量数据

### trojan-eye面板![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232616089-c03a5dbb-541c-4710-8199-d2db21154503.png)

- 收集器用于实时接收容器的web流量
- 标记器用于将收集器关注的数据进行统计归类
- 设置主要配置数据的持久化问题（推荐内存模式，Mongodb支持不是很好）

### 监听器：发送监听指令![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232641666-db5c9489-d71e-400c-9bc3-4fd301a73116.png)

在监听器中点击创建，然后输入地址等信息，其中：

- 标签：用于表示流量是由那个监听器接收产生
- 注入地址：用于向目标网站注入websocket服务，推荐填写目标服务真实存在的url（如目标服务器的登录url:http://x.x.x.x/login,这样每次注入websocket服务时，都通过登录页面进行注入）
- 监听地址：用于创建指定的websocket的服务，默认禁止以网站根目录进行注册websocket（如目标服务存在ws://x.x.x.x/meeting/websocket，可以注入ws://x.x.x.x/meeting/websockets这样迷惑的websocket服务）

在创建结束后，需要手动发起连接请求：![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232653922-768a4bc3-9236-4df3-a015-e1319957e008.png)

如果需要暂时停止监听，可直接点击关闭连接，注销则直接发送指令，服务器直接注销对应的websocket服务

### 收集器：动态的实时数据![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232668182-3e034bab-cb94-4eec-894f-0055db8588ef.png)

收集器的数据都是在监听数据到来的第一时间就展示到此面板中。由于默认内存模式，如果关闭页面，数据就会立即丢失，所以加入快捷方式，用于任意时刻持久化数据

### 标识器：静态数据![img](https://cdn.nlark.com/yuque/0/2022/png/1599979/1661232677817-0dbbe2b3-0d79-45fe-ba3b-3dd17d6e7841.png)

收集器的每一条数据都有转发标识的选项，当转发后，数据就会转发到标识器中。此面板的数据只能从收集器中获取。另外提供装载按钮，用于将之前存储的数据加载进来

## 帮助

- 收集器实时接收监听数据
- 标记器只接收收集器关注数据
- 数据库模式并不支持快捷方式的操作(对Mongodb数据库的功能并没有做太多想法)
- ctrl + s (内存策略): 将标记器的数据持久化到配置指定目录的markData
- ctrl + shift + s (内存策略): 将收集器的数据持久化到配置指定目录的dynamicData, 标记器的数据持久化到配置指定目录的markData
- ctrl + d (内存策略): 将标记器的数据清空(内存中的数据)
- ctrl + shift + d (内存策略): 将标记器和收集器的数据清空(内存中的数据)
- 内存数据容易丢失，不会自动保存
