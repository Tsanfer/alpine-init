# Alpine Server Init

alpine-init.sh 是一个面向 Alpine Linux 服务器的交互式初始化脚本。

## 快速开始

使用 root 执行：

~~~sh
chmod +x /root/alpine-init.sh
sh /root/alpine-init.sh
~~~

脚本启动时会先选择服务器网络环境：

- 国内/中国大陆：第 1 项可更换为国内 Alpine 软件源
- 国外/海外：第 1 项会提示通常无需更换并跳过

每次只执行一个功能。功能执行结束后会暂停，按回车返回主菜单；输入 0 退出脚本。

## 功能菜单

| 编号 | 功能 |
| --- | --- |
| 1 | 更换 Alpine 软件源，仅国内环境执行 |
| 2 | 更新 apk 索引 |
| 3 | 升级已安装软件包 |
| 4 | 更新 Alpine 系统，包括内核和发行版 |
| 5 | 安装基础软件 |
| 6 | 安装常用软件 |
| 7 | 查看系统配置 |
| 8 | 调整时区 |
| 9 | 调整主机名 |
| 10 | 配置 Swap / zswap |
| 11 | 启用 tun 内核模块 |
| 12 | 配置 SSH Root、密码和密钥登录 |
| 13 | 安装 Docker / Compose |
| 14 | 配置 Docker 镜像加速并自动检测 |
| 15 | 重启服务器 |
| 0 | 退出 |

## 重点功能

### Alpine 系统升级

第 4 项会显示：

- 当前 Alpine 版本
- 当前软件源分支
- 官方最新稳定版本
- 当前运行内核
- 已安装内核包和仓库可用版本

交互模式提供：

1. 仅更新内核
2. 仅升级当前发行版
3. 更新内核并升级到最新稳定版
0. 取消


### 基础软件

第 5 项会先列出软件及作用，可输入多个编号，直接回车默认全选。

软件包括：

- curl：HTTP/HTTPS 下载和接口调用
- bash：功能更完整的 Shell
- jq：处理 JSON
- wget：文件下载
- git：版本控制
- vim：终端编辑器
- bottom：终端系统监控，命令为 btm
- tmux：终端会话管理
- unzip：解压 ZIP 文件
- fastfetch：查看系统和硬件信息

bottom 和 fastfetch 使用 Alpine 官方仓库安装。安装 bottom 后会写入：

~~~text
/root/.config/bottom/bottom.toml
~~~

配置内容包括缓存内存、网络字节数和进程命令行显示。

安装或查看系统配置时，fastfetch 会自动显示系统信息。温度参数未启用，以兼容 Alpine 官方仓库中的 fastfetch 版本。

### 常用软件

第 6 项用于安装开发环境常用命令，可选择：

- npx：Node.js 包执行工具，实际安装 Alpine 的 npm 包
- pip3：Python 3 软件包安装工具，实际安装 Alpine 的 py3-pip 包

直接回车默认安装 npx 和 pip3。

国内环境安装完成后会自动配置软件源：

~~~sh
npm config set registry https://registry.npmmirror.com/
pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
~~~

国外/海外环境会保留 npm 和 PyPI 官方源。

### Swap / zswap

第 10 项进入专用子菜单，可执行：

1. 创建或重新配置 /swapfile
2. 开启并配置 zswap 缓存比例
3. 查看 Swap、zswap 和 free -h 状态
0. 返回主菜单

Swap 文件默认大小为 2048 MiB，并会写入 /etc/fstab。

zswap 是现有 Swap 的压缩缓存，不会自行创建 Swap。没有 Swap 文件或 Swap 分区时，free -h 仍会显示：

~~~text
Swap: 0 0 0
~~~

### SSH

第 12 项会先检测：

- /root/.ssh/authorized_keys 中是否已有公钥
- root 密码是否已设置且未锁定

SSH 登录策略默认开启：

- Root 登录
- 密码登录
- 公钥登录

只有 SSH 配置或登录凭证实际发生变化时才会重启 sshd。配置未变化且服务已运行时，不会重启服务。修改配置前会创建备份，并使用 sshd -t 校验。

### Docker

第 13 项安装 Docker、Docker Compose，并使用 Alpine OpenRC 管理服务。

第 14 项写入 Docker 镜像加速配置。配置完成后会自动检测 Docker 是否读取到镜像加速地址。

## 命令参数

~~~text
-r, --region cn|global
    指定网络环境，cn 为国内，global 为国外/海外

-y, --yes
    非交互模式，按脚本预设顺序执行无需人工输入的功能

--docker-mirrors "LIST"
    指定空格分隔的 Docker 镜像加速地址

--skip-linux-mirror
    跳过 Alpine 软件源更换

--skip-upgrade
    跳过普通 apk upgrade

--skip-docker
    跳过 Docker 安装和镜像加速配置
~~~

示例：

~~~sh
sh /root/alpine-init.sh --region cn
sh /root/alpine-init.sh --region global
sh /root/alpine-init.sh --region cn --docker-mirrors "https://docker.m.daocloud.io"
sh /root/alpine-init.sh --region global -y
~~~

## 注意事项

- 仅支持 Alpine Linux，并要求使用 root 执行。
- 修改软件源前会尝试保留原配置备份。
- 跨发行版升级前会备份 /etc/apk/repositories。
- 创建 Swap 文件会占用磁盘空间，请根据服务器内存和磁盘容量选择大小。
- 跨发行版升级、启用内核参数、zswap 和 tun 可能需要重启后完全生效。
- 建议在云服务器控制台或带外管理可用的情况下执行涉及 SSH、内核和重启的操作。
