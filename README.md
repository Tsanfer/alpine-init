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
| 9 | 查看系统配置 |
| 10 | 启用 tun 内核模块 |
| 11 | 安装 Docker / Compose |
| 12 | 配置 Docker 镜像加速并自动检测 |
| 13 | 安装常用 Docker 容器 |
| 14 | 调整时区 |
| 15 | 调整主机名 |
| 16 | 重启服务器 |
| 0 | 退出（主菜单也支持 q） |

### 基础软件

- 进入第 7 项时会先显示每个软件当前是“已安装”还是“未安装”。选择已安装的软件会自动跳过重复安装。
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

- 进入第 8 项时会先检查 `npm` 和 `py3-pip` 是否已安装，已安装的软件会自动跳过重复安装。
- npx：Node.js 包执行工具，实际安装 Alpine 的 npm 包
- pip3：Python 3 软件包安装工具，实际安装 Alpine 的 py3-pip 包

国内环境安装完成后会自动配置软件源。

### 常用 Docker 容器

第 11 项会先显示 Docker / Compose 是否已安装，已完整安装时跳过重复安装，只补充缺失组件。

第 13 项目前提供 `nginx-proxy-manager`。菜单会先显示容器状态：未部署、已配置未启动、已存在但未运行或已运行。已存在的容器不会重复创建。

安装完成后脚本会自动检测服务器 IP，并显示管理面板地址（端口 `81`）。首次登录默认账号为 `admin@example.com`，默认密码为 `changeme`，登录后请立即修改。

### 回车默认行为

- 基础软件、常用软件和 Docker 容器：直接回车返回，不执行安装；输入编号后才检查并处理。
- Alpine 系统、内核和发行版升级：直接回车取消。
- SSH、时区、主机名、Swap / zswap、tun 和重启等功能：需要根据提示明确输入或确认。
- 主菜单推荐使用 `0` 退出；同时兼容输入 `q` 或 `Q`。

## 命令参数

~~~text
-r, --region cn|global
    指定网络环境：cn 为国内，global 为国外/海外。
    不指定时，脚本启动后会交互询问。
~~~

其他初始化功能通过主菜单手动选择，不需要额外命令参数。
