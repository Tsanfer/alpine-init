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

也可以使用下面的完整脚本，根据提示选择网络地址，并自动在 curl 和 wget 之间切换：
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

if command -v curl >/dev/null 2>&1; then
    script="$(curl -fsSL "$url")" || {
        echo "脚本下载失败" >&2
        exit 1
    }
elif command -v wget >/dev/null 2>&1; then
    script="$(wget -qO- "$url")" || {
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

### 常用软件

第 6 项用于安装开发环境常用命令，可选择：

- npx：Node.js 包执行工具，实际安装 Alpine 的 npm 包
- pip3：Python 3 软件包安装工具，实际安装 Alpine 的 py3-pip 包

国内环境安装完成后会自动配置软件源。

## 命令参数

~~~text
-r, --region cn|global
    指定网络环境：cn 为国内，global 为国外/海外。
    不指定时，脚本启动后会交互询问。
~~~

其他初始化功能通过主菜单手动选择，不需要额外命令参数。
