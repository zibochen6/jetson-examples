# Jetson 本地浏览器 Agent：Laya + Qwen

> 当前为预览版：Docker 镜像及完整实机验收尚未完成。启动器会拒绝运行没有完成镜像身份校验的版本，详见验证记录。

在 reComputer Industrial J4012 / Orin NX 16GB 上，通过自然语言操作 Trip.com
查询航班，或连续编辑本地白板。Docker 完整镜像包含应用、CUDA 环境、Chromium、
Laya 和 Qwen 权重、已编译的 llama.cpp；启动时不再安装依赖或下载模型。

[完整英文说明](README.md) · [Seeed Wiki 原理与演示](https://wiki.seeedstudio.com/jetson/local_decision_model_laya/)

![航班查询：设置条件、读取真实结果、打开票价选项](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-flight-search-demo.gif)

![白板：在同一画布上创建、改色并增加连接](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-whiteboard-demo.gif)

两张动态图直接复用 Wiki 原文件，展示已有应用能力。Docker 版实测另见
[验证记录](VALIDATION.md)，不把旧演示耗时当作新镜像成绩。

## 环境与运行

首发支持 Orin NX **16GB**、L4T **36.4.3**、已登录的 **X11** 桌面。
宿主需已有 Docker、Compose v2、NVIDIA Runtime、xauth，并允许当前普通用户使用 Docker。
启动器不升级 JetPack、不修改系统 Python。磁盘要求见 `release.json`。

从包含本案例的源码仓库安装：

```bash
pip3 install .
reComputer run laya-browser check
reComputer run laya-browser
```

首次拉取完整镜像后加载模型，出现 `Task>` 再输入英文任务。浏览器显示在 Jetson
桌面上，不自动录屏。日期需使用未来的 `YYYY-MM-DD`：

```text
Find one-way flights from Shenzhen to Shanghai on 2026-12-15 for 1 adult in economy. Nonstop only, lowest price first. Show up to 3 options and open the fare options for one matching flight.
```

查询仅支持单程、1 名成人、经济舱。程序核对路线、日期、直飞、排序和票价选项；
不提交订单或付款。验证码由用户处理，网站内容和价格会变化。

完成后输入 `exit` 退出提示符，再启动白板：

```bash
reComputer run laya-browser whiteboard
```

白板英文示例见英文说明。Qwen 解析需求，Laya 选择候选动作，程序通过鼠标键盘执行并独立核对。
支持小型方框、文字和箭头图；布局由程序计算。

## 停止与保存

- 运行中按 Ctrl+C：取消任务，等待回到提示符。
- 提示符输入 `exit`：退出终端会话，模型和浏览器保留。
- `reComputer run laya-browser status`：查看状态。
- `reComputer clean laya-browser`：停止并移除本案例容器，保留镜像与数据。

数据默认保存在 `~/reComputer/laya-browser/persistent/`，包括浏览器配置、日志、
任务记录、白板可编辑文件及图片。可通过 `JETSON_LAYA_HOME` 指定新的绝对路径；
后续启动和清理必须使用相同路径。容器重建后恢复数据，不自动重放旧任务。

拉取镜像、加载模型和等待输入不计入任务计时。任务解析、浏览器操作、网站等待、
核对和保存均计入。首次安装大小、加载耗时和任务结果以 Docker 验证记录为准。

离线设备可先导入同版本完整镜像，白板不依赖外部模型/CDN；查询航班仍需联网。
更新前完成任务并停止案例，保留数据备份和旧镜像；不会自动跟随 `latest`。
