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
~~~
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
| 12 | 安装常用 Docker 容器 |
| 13 | 管理 Docker 容器 |
| 14 | 查看系统配置 |
| 15 | 调整时区 |
| 16 | 调整主机名 |
| 17 | 重启服务器 |
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

### 常用软件

| 软件 | 作用 | 命令 |
| --- | --- | --- |
| `npx` | Node.js 包执行工具 | `npx` |
| `pip3` | Python 3 软件包安装工具 | `pip3` |

国内环境安装完成后会自动配置软件源。

### 常用 Docker 容器

| 容器 | 作用 | 镜像 | 端口 | 数据目录 |
| --- | --- | --- | --- | --- |
| `nginx-proxy-manager` | Web 反向代理<br>SSL 证书<br>域名管理 | `jc21/nginx-proxy-manager:latest` | `80` HTTP<br>`81` 管理面板<br>`443` HTTPS | `/opt/nginx-proxy-manager/data`<br>`/opt/nginx-proxy-manager/letsencrypt` |

安装完成后脚本会自动检测服务器 IP，并显示管理面板地址（端口 `81`）。首次登录默认账号为 `admin@example.com`，默认密码为 `changeme`，登录后请立即修改。

第 13 项用于管理已有 Docker 容器，可选择启动、停止、重启或删除容器。删除操作需要再次确认，只删除容器本身，不会自动删除数据卷或绑定目录。

第 14 项用于查看系统配置。若未安装 fastfetch，脚本会先从 Alpine 官方仓库安装，然后显示系统信息。

## 命令参数

~~~text
-r, --region cn|global
    指定网络环境：cn 为国内，global 为国外/海外。
    不指定时，脚本启动后会交互询问。
~~~

其他初始化功能通过主菜单手动选择，不需要额外命令参数。
