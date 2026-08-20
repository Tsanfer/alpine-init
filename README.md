# Alpine Init

一个面向 Alpine Linux 服务器的交互式初始化脚本。

## 快速开始

国内环境运行：

~~~sh
sh -c "$(wget -qO- 'https://gh-proxy.org/https://raw.githubusercontent.com/Tsanfer/alpine-init/main/alpine-init.sh')"
~~~

国外/海外环境运行：

~~~sh
sh -c "$(wget -qO- 'https://raw.githubusercontent.com/Tsanfer/alpine-init/main/alpine-init.sh')"
~~~

如果没有 wget，可将 `wget -qO- URL` 替换为 `curl -fsSL URL`。

也可以使用下面的完整脚本，根据提示选择网络地址，并优先使用 wget，缺少 wget 时再使用 curl：
~~~sh
printf "是否从国内代理拉取脚本？[Y/n] "
read -r choice
if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
    url="https://raw.githubusercontent.com/Tsanfer/alpine-init/main/alpine-init.sh"
else
    url="https://gh-proxy.org/https://raw.githubusercontent.com/Tsanfer/alpine-init/main/alpine-init.sh"
fi

if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    echo "请先使用 root，或安装 sudo" >&2
    exit 1
fi

if command -v wget >/dev/null 2>&1; then
    script="$(wget -qO- "$url")" || {
        echo "脚本下载失败" >&2
        exit 1
    }
elif command -v curl >/dev/null 2>&1; then
    script="$(curl -fsSL "$url")" || {
        echo "脚本下载失败" >&2
        exit 1
    }
else
    echo "请先安装 curl 或 wget" >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    sh -c "$script"
else
    sudo sh -c "$script"
fi
~~~
## 功能菜单

| 编号 | 功能 |
| --- | --- |
| 1 | 更换 Alpine 软件源，仅国内环境执行 |
| 2 | 配置 SSH Root、密码和密钥登录 |
| 3 | 配置 Swap / zswap |
| 4 | 更新 apk 索引 |
| 5 | 升级已安装软件包 |
| 6 | 更新 Alpine 系统，包括内核和发行版 |
| 7 | 安装基础软件 |
| 8 | 安装常用软件 |
| 9 | 启用 tun 内核模块 |
| 10 | 安装 Docker / Compose |
| 11 | 配置 Docker 镜像加速并自动检测 |
| 12 | 安装 Docker 面板 |
| 13 | 查看系统配置 |
| 14 | 调整时区 |
| 15 | 调整主机名 |
| 16 | 重启服务器 |
| 0 | 退出（主菜单也支持 q） |

### 基础软件

| 软件 | 作用 | 命令 |
| --- | --- | --- |
| `curl` | HTTP/HTTPS 下载和接口调用 | `curl` |
| `bash` | 功能更完整的 Shell | `bash` |
| `jq` | 处理 JSON | `jq` |
| `wget` | 文件下载 | `wget` |
| `git` | 版本控制 | `git` |
| `vim` | 终端编辑器 | `vim` |
| `bottom` | 终端系统监控 | `btm` |
| `tmux` | 终端会话管理 | `tmux` |
| `unzip` | 解压 ZIP 文件 | `unzip` |
| `fastfetch` | 查看系统和硬件信息 | `fastfetch` |
| `tar` | 打包和解包归档文件 | `tar` |
| `gzip` | Gzip 压缩和解压 | `gzip` |

### 常用软件

| 软件 | 作用 | 命令 |
| --- | --- | --- |
| `npx` | Node.js 包执行工具 | `npx` |
| `pip3` | Python 3 软件包安装工具 | `pip3` |

国内环境安装完成后会自动配置软件源。

### Docker 管理面板

第 12 项会调用 DPanel 官方安装器。也可以按 [DPanel 官方安装文档](https://dpanel.cc/install/shell) 手动安装：

~~~sh
curl -sSL https://dpanel.cc/quick.sh | bash
~~~

DPanel 安装器支持安装、更新和卸载。执行前请确认 Docker 已安装并运行，当前用户具有 Docker Socket 操作权限；安装后的访问端口和登录信息以 DPanel 输出为准。

## 命令参数

~~~text
-r, --region cn|global
    指定网络环境：cn 为国内，global 为国外/海外。
    不指定时，脚本启动后会交互询问。
~~~

其他初始化功能通过主菜单手动选择，不需要额外命令参数。
