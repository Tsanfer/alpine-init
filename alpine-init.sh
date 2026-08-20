#!/bin/sh
set -eu

LINUXMIRRORS_URL="https://linuxmirrors.cn/main.sh"
REGION=""
ASSUME_YES=0
SKIP_LINUX_MIRROR=0
SKIP_UPGRADE=0
SKIP_DOCKER=0
DOCKER_MIRRORS=""
ACTION=""

log() {
    printf '\033[1;32m[INFO]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[WARN]\033[0m %s\n' "$*"
}

die() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Alpine server init script

Usage:
  sh alpine-init.sh [options]

Options:
  -r, --region cn|global       运行环境：cn=国内，global=国外/海外
  -y, --yes                    非交互模式，按顺序执行无需人工输入的功能
      --docker-mirrors "LIST"  指定空格分隔的 Docker registry mirror 列表
      --skip-linux-mirror      跳过 Linux 软件源更换
      --skip-upgrade           跳过 apk upgrade
      --skip-docker            跳过 Docker 安装和配置
  -h, --help                   显示帮助

Examples:
  sh alpine-init.sh
  sh alpine-init.sh --region cn -y
  sh alpine-init.sh --region cn --docker-mirror https://docker.m.daocloud.io
  sh alpine-init.sh --region global -y
EOF
}

append_docker_mirror() {
    url="$1"
    [ -n "$url" ] || die "Docker mirror URL 不能为空"
    case "$url" in
        *\"*|*\\*|*' '*|*'	'*)
            die "Docker mirror URL 含有不支持的字符：$url"
            ;;
        http://*|https://*)
            DOCKER_MIRRORS="${DOCKER_MIRRORS}${DOCKER_MIRRORS:+ }$url"
            ;;
        *)
            die "Docker mirror URL 必须以 http:// 或 https:// 开头：$url"
            ;;
    esac
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -r|--region)
                [ "$#" -ge 2 ] || die "$1 需要参数：cn 或 global"
                REGION="$2"
                shift 2
                ;;
            -y|--yes)
                ASSUME_YES=1
                shift
                ;;
            --docker-mirror)
                [ "$#" -ge 2 ] || die "$1 需要 URL 参数"
                append_docker_mirror "$2"
                shift 2
                ;;
            --docker-mirrors)
                [ "$#" -ge 2 ] || die "$1 需要 URL 列表参数"
                for mirror in $2; do
                    append_docker_mirror "$mirror"
                done
                shift 2
                ;;
            --skip-linux-mirror)
                SKIP_LINUX_MIRROR=1
                shift
                ;;
            --skip-upgrade)
                SKIP_UPGRADE=1
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "未知参数：$1"
                ;;
        esac
    done
}

ask_region() {
    if [ -n "$REGION" ]; then
        return
    fi

    if [ "$ASSUME_YES" -eq 1 ]; then
        REGION="cn"
        return
    fi

    while :; do
        printf '\n========================================\n'
        printf '         服务器网络环境\n'
        printf '========================================\n'
        printf '  1) 国内 / 中国大陆\n'
        printf '  2) 国外 / 海外\n'
        printf '----------------------------------------\n'
        printf '请选择网络环境 [1]（0/q 退出）: '
        read -r choice
        if has_nonprintable_input "$choice"; then
            continue
        fi
        case "${choice:-1}" in
            1|cn|CN|china|China)
                REGION="cn"
                return
                ;;
            2|global|GLOBAL|abroad|Abroad|oversea|Oversea)
                REGION="global"
                return
                ;;
            0|q|Q)
                log "已退出初始化脚本"
                exit 0
                ;;
            *)
                die "无效选择：$choice"
                ;;
        esac
    done
}

normalize_region() {
    case "$REGION" in
        cn|CN|china|China|mainland|Mainland)
            REGION="cn"
            ;;
        global|GLOBAL|abroad|Abroad|oversea|Oversea|foreign|Foreign)
            REGION="global"
            ;;
        *)
            die "REGION 只能是 cn 或 global，当前为：$REGION"
            ;;
    esac
}

has_nonprintable_input() {
    case "$1" in
        *[![:print:]]*) return 0 ;;
        *) return 1 ;;
    esac
}

show_action_menu() {
    printf "\n========================================\n"
    printf " Alpine 服务器初始化 | 环境：%s\n" "$REGION"
    printf "========================================\n"
    printf "  1) 更换软件源(国内)\n"
    printf "  2) 配置 SSH 登录\n"
    printf "  3) 配置 Swap / zswap\n"
    printf "  4) 更新 apk 索引\n"
    printf "  5) 升级已安装软件包\n"
    printf "  6) 更新系统(内核/发行版)\n"
    printf "  7) 安装基础软件\n"
    printf "  8) 安装常用软件\n"
    printf "  9) 启用 tun 模块\n"
    printf " 10) 安装 Docker/Compose\t[当前：%s]\n" "$(docker_install_status)"
    printf " 11) 配置 Docker 镜像加速\n"
    printf " 12) 管理 Docker 容器\n"
    printf " 13) 查看系统配置\n"
    printf " 14) 调整时区\n"
    printf " 15) 调整主机名\n"
    printf " 16) 重启服务器\n"
    printf "  0) 退出（也可输入 q）\n"
    printf "----------------------------------------\n"
}

read_action() {
    show_action_menu
    printf "请输入编号（0/q 退出）: "
    if ! read -r action; then
        printf "\n"
        ACTION="0"
        return
    fi
    if has_nonprintable_input "$action"; then
        ACTION="__ignore__"
        return
    fi
    case "$action" in
        q|Q) ACTION="0" ;;
        *) ACTION="$action" ;;
    esac
}



check_root_and_os() {
    [ "$(id -u)" -eq 0 ] || die "请使用 root 运行"
    [ -f /etc/alpine-release ] || die "当前系统不是 Alpine Linux，已停止"
    command -v apk >/dev/null 2>&1 || die "未找到 apk，当前系统不像 Alpine"
}

alpine_branch() {
    version="$(cat /etc/alpine-release)"
    case "$version" in
        edge*)
            printf 'edge'
            ;;
        [0-9]*.[0-9]*)
            major="$(printf '%s' "$version" | cut -d. -f1)"
            minor="$(printf '%s' "$version" | cut -d. -f2)"
            printf 'v%s.%s' "$major" "$minor"
            ;;
        *)
            printf 'latest-stable'
            ;;
    esac
}

manual_configure_apk_repos() {
    branch="$(alpine_branch)"
    if [ "$REGION" = "cn" ]; then
        base="https://mirrors.aliyun.com/alpine"
    else
        base="https://dl-cdn.alpinelinux.org/alpine"
    fi

    backup="/etc/apk/repositories.bak.$(date +%Y%m%d%H%M%S)"
    if [ -f /etc/apk/repositories ]; then
        cp /etc/apk/repositories "$backup"
        log "已备份 /etc/apk/repositories 到 $backup"
    fi

    cat > /etc/apk/repositories <<EOF
$base/$branch/main
$base/$branch/community
EOF
    log "已手动配置 Alpine 软件源：$base/$branch/{main,community}"
}

install_bootstrap_tools() {
    missing=""
    command -v bash >/dev/null 2>&1 || missing="$missing bash"
    command -v curl >/dev/null 2>&1 || missing="$missing curl"
    command -v ca-certificates >/dev/null 2>&1 || missing="$missing ca-certificates"

    if [ -n "$missing" ]; then
        log "安装基础工具：$missing"
        if ! apk add --no-cache $missing; then
            warn "当前软件源安装基础工具失败，先回退为手动写入 Alpine 软件源"
            manual_configure_apk_repos
            apk update
            apk add --no-cache $missing
        fi
    fi

    update-ca-certificates >/dev/null 2>&1 || true
}

run_linuxmirrors() {
    [ "$SKIP_LINUX_MIRROR" -eq 0 ] || {
        warn "已跳过 Linux 软件源更换"
        return
    }

    if [ "$REGION" != "cn" ]; then
        warn "当前为国外/海外环境，通常无需更换 Alpine 软件源，已跳过"
        return
    fi

    install_bootstrap_tools

    tmp_script="$(mktemp)"
    trap 'rm -f "$tmp_script"' EXIT
    curl -fsSL "$LINUXMIRRORS_URL" -o "$tmp_script"

    # Alpine 的 musl regex 不支持 linuxmirrors 脚本使用的 [:ascii:] 字符类。
    if grep -Fq '[:ascii:]' "$tmp_script"; then
        sed -i 's/\[:ascii:\]/[:print:]/g' "$tmp_script"
        log "已应用 Alpine 正则兼容性修正"
    fi

    log "通过 linuxmirrors.cn 更换 Alpine 软件源"
    if [ "$REGION" = "cn" ]; then
        if ! bash "$tmp_script" \
            --source mirrors.aliyun.com \
            --protocol https \
            --backup true \
            --upgrade-software false \
            --clean-cache false \
            --clean-screen false \
            --pure-mode \
            --ignore-backup-tips; then
            warn "linuxmirrors.cn 执行失败，改用手动写入国内 Alpine 源"
            manual_configure_apk_repos
        fi
    else
        if ! bash "$tmp_script" \
            --abroad \
            --use-official-source true \
            --protocol https \
            --backup true \
            --upgrade-software false \
            --clean-cache false \
            --clean-screen false \
            --pure-mode \
            --ignore-backup-tips; then
            warn "linuxmirrors.cn 执行失败，改用手动写入官方 Alpine 源"
            manual_configure_apk_repos
        fi
    fi
}

update_apk_index() {
    log "更新 apk 索引"
    apk update
}

upgrade_system() {
    log "升级已安装软件包"
    apk upgrade --available
}

install_docker() {
    [ "$SKIP_DOCKER" -eq 0 ] || {
        warn "已跳过 Docker 安装"
        return
    }

    if command -v docker >/dev/null 2>&1 && docker_compose_command >/dev/null 2>&1; then
        log "Docker 和 Docker Compose 已安装，跳过重复安装"
        return 0
    fi

    log "检查到 Docker / Compose 尚未完整安装，补充安装缺失组件"
    if ! apk add --no-cache docker docker-cli docker-cli-compose; then
        warn "docker-cli-compose 安装失败，尝试旧包名 docker-compose"
        apk add --no-cache docker docker-cli docker-compose
    fi
}

default_docker_mirrors() {
    if [ -n "$DOCKER_MIRRORS" ]; then
        return
    fi

    if [ "$REGION" = "cn" ]; then
        DOCKER_MIRRORS="https://docker.m.daocloud.io https://docker.1ms.run"
    fi
}

write_docker_daemon_config() {
    [ "$SKIP_DOCKER" -eq 0 ] || return
    default_docker_mirrors

    mkdir -p /etc/docker

    if [ -z "$DOCKER_MIRRORS" ]; then
        log "国外环境默认使用 Docker Hub 官方源，不写入 registry-mirrors"
        return
    fi

    if [ -s /etc/docker/daemon.json ]; then
        backup="/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
        cp /etc/docker/daemon.json "$backup"
        warn "已备份现有 Docker 配置到 $backup"
    fi

    {
        printf '{\n'
        printf '  "registry-mirrors": [\n'
        first=1
        for mirror in $DOCKER_MIRRORS; do
            if [ "$first" -eq 1 ]; then
                first=0
            else
                printf ',\n'
            fi
            printf '    "%s"' "$mirror"
        done
        printf '\n'
        printf '  ]\n'
        printf '}\n'
    } > /etc/docker/daemon.json

    log "已写入 Docker 镜像源：$DOCKER_MIRRORS"
}


detect_docker_mirror() {
    [ "$SKIP_DOCKER" -eq 0 ] || return

    if [ ! -f /etc/docker/daemon.json ]; then
        warn "未找到 /etc/docker/daemon.json，跳过检测"
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker 客户端未安装，配置已写入 /etc/docker/daemon.json"
        return 0
    fi

    if docker info >/tmp/docker-info.txt 2>/dev/null; then
        if [ -n "$DOCKER_MIRRORS" ]; then
            if grep -A20 "Registry Mirrors" /tmp/docker-info.txt | grep -F "https://" >/dev/null 2>&1; then
                log "Docker 镜像加速检测通过"
                grep -A20 "Registry Mirrors" /tmp/docker-info.txt || true
            else
                warn "Docker 已运行，但未在 docker info 中看到 Registry Mirrors，可能需要等待 Docker 自动重载"
            fi
        else
            log "Docker 配置已写入"
        fi
    else
        warn "Docker 当前未运行，配置已写入 /etc/docker/daemon.json，等 Docker 启动后自动生效"
    fi
}

docker_compose_command() {
    if docker compose version >/dev/null 2>&1; then
        printf 'docker compose'
    elif command -v docker-compose >/dev/null 2>&1; then
        printf 'docker-compose'
    else
        return 1
    fi
}

package_is_installed() {
    apk info -e "$1" >/dev/null 2>&1
}

package_status() {
    if package_is_installed "$1"; then
        printf "✅ 已安装"
    else
        printf "⬜ 未安装"
    fi
}

display_width() {
    display_text="$1"
    display_chars="$(printf '%s' "$display_text" | wc -m)"
    display_non_ascii="$(printf '%s\n' "$display_text" | awk '{ text=$0; print gsub(/[^ -~]/, "", text) }')"
    printf '%s' "$((display_chars + display_non_ascii))"
}

print_status_column() {
    status_column="$1"
    description_start="$2"
    description="$3"
    status="$4"
    description_width="$(display_width "$description")"
    padding=$((status_column - description_start - description_width))
    [ "$padding" -gt 0 ] || padding=1
    printf "%*s[%s]\n" "$padding" "" "$status"
}

print_package_item() {
    item_number="$1"
    item_name="$2"
    item_description="$3"
    item_package="$4"

    item_status="$(package_status "$item_package")"
    printf "  %2s) %-10s\t%s" "$item_number" "$item_name" "$item_description"
    print_status_column 48 17 "$item_description" "$item_status"
}

docker_install_status() {
    if command -v docker >/dev/null 2>&1 && docker_compose_command >/dev/null 2>&1; then
        printf "✅ 已安装"
    elif command -v docker >/dev/null 2>&1; then
        printf "⚠️ Docker 已安装，Compose 未安装"
    else
        printf "⬜ 未安装"
    fi
}

manage_docker_containers() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "未找到 Docker，请先执行第 10 项安装 Docker / Compose"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        warn "Docker 服务未运行或当前用户无权访问 Docker"
        return 1
    fi

    while :; do
        printf "\n----------------------------------------\n"
        printf "Docker 容器管理\n"
        printf "----------------------------------------\n"
        container_names="$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)"
        if [ -z "$container_names" ]; then
            warn "当前没有 Docker 容器"
            return 2
        fi

        container_index=0
        for container_name in $container_names; do
            container_index=$((container_index + 1))
            container_status="$(docker ps -a --filter "name=^/$container_name$" --format '{{.Status}}' 2>/dev/null | sed -n '1p')"
            printf "  %2s) %-24s\t%s\n" "$container_index" "$container_name" "$container_status"
        done

        printf "请输入容器编号（0/q 返回主菜单）: "
        read -r selected_index || selected_index="0"
        if has_nonprintable_input "$selected_index"; then
            continue
        fi
        case "$selected_index" in
            0|q|Q)
                return 2
                ;;
        esac

        case "$selected_index" in
            ''|*[!0-9]*)
                warn "请输入有效的容器编号"
                continue
                ;;
        esac

        selected_container=""
        container_index=0
        for container_name in $container_names; do
            container_index=$((container_index + 1))
            if [ "$container_index" -eq "$selected_index" ]; then
                selected_container="$container_name"
                break
            fi
        done

        if [ -z "$selected_container" ]; then
            warn "无效容器编号：$selected_index"
            continue
        fi

        while :; do
            printf "\n容器：%s\n" "$selected_container"
            printf "  1) 启动容器\n"
            printf "  2) 停止容器\n"
            printf "  3) 重启容器\n"
            printf "  4) 删除容器\n"
            printf "  0) 返回容器列表（q 也可以）\n"
            printf "请输入操作编号: "
            read -r container_action || container_action="0"
            if has_nonprintable_input "$container_action"; then
                continue
            fi

            case "$container_action" in
                1)
                    if docker start "$selected_container"; then
                        log "容器已启动：$selected_container"
                    else
                        warn "容器启动失败：$selected_container"
                    fi
                    break
                    ;;
                2)
                    if docker stop "$selected_container"; then
                        log "容器已停止：$selected_container"
                    else
                        warn "容器停止失败：$selected_container"
                    fi
                    break
                    ;;
                3)
                    if docker restart "$selected_container"; then
                        log "容器已重启：$selected_container"
                    else
                        warn "容器重启失败：$selected_container"
                    fi
                    break
                    ;;
                4)
                    warn "删除操作只移除容器，不会自动删除数据卷或绑定目录"
                    printf "确认删除容器 %s？输入 y 继续，直接回车取消: " "$selected_container"
                    read -r confirm_delete || confirm_delete=""
                    if [ "$confirm_delete" = "y" ] || [ "$confirm_delete" = "Y" ]; then
                        if docker rm -f "$selected_container"; then
                            log "容器已删除：$selected_container"
                        else
                            warn "容器删除失败：$selected_container"
                        fi
                    else
                        warn "已取消删除容器"
                    fi
                    break
                    ;;
                0|q|Q)
                    break
                    ;;
                *)
                    warn "无效操作编号：$container_action"
                    ;;
            esac
        done
    done
}

ensure_download_tools() {
    missing_download_tools=""
    command -v curl >/dev/null 2>&1 || missing_download_tools="$missing_download_tools curl"
    [ -f /etc/ssl/certs/ca-certificates.crt ] || missing_download_tools="$missing_download_tools ca-certificates"

    if [ -n "$missing_download_tools" ]; then
        log "安装网络下载所需工具：$missing_download_tools"
        apk add --no-cache $missing_download_tools
        update-ca-certificates >/dev/null 2>&1 || true
    fi
}

configure_bottom() {
    bottom_config_dir="/root/.config/bottom"
    bottom_config="$bottom_config_dir/bottom.toml"
    mkdir -p "$bottom_config_dir"

    if [ -f "$bottom_config" ]; then
        cp "$bottom_config" "$bottom_config.bak.$(date +%Y%m%d%H%M%S)"
    fi

    bottom_config_tmp="$(mktemp)"
    if [ -f "$bottom_config" ]; then
        awk '
            function print_flags() {
                print "enable_cache_memory = true"
                print "network_use_bytes = true"
                print "process_command = true"
            }
            /^[[:space:]]*\[flags\][[:space:]]*$/ {
                print
                in_flags = 1
                found_flags = 1
                next
            }
            /^[[:space:]]*\[/ {
                if (in_flags && !inserted) {
                    print_flags()
                    inserted = 1
                }
                in_flags = 0
                print
                next
            }
            /^[[:space:]]*(enable_cache_memory|network_use_bytes|process_command)[[:space:]]*=/ {
                next
            }
            {
                print
            }
            END {
                if (in_flags && !inserted) {
                    print_flags()
                    inserted = 1
                }
                if (!found_flags) {
                    print ""
                    print "[flags]"
                    print_flags()
                }
            }
        ' "$bottom_config" > "$bottom_config_tmp"
    else
        {
            printf '[flags]\n'
            printf 'enable_cache_memory = true\n'
            printf 'network_use_bytes = true\n'
            printf 'process_command = true\n'
        } > "$bottom_config_tmp"
    fi
    mv "$bottom_config_tmp" "$bottom_config"
    log "已写入 bottom 配置：[flags] -> $bottom_config"
}

install_bottom() {
    if package_is_installed bottom; then
        log "bottom 已安装，跳过重复安装"
    else
        log "安装 Alpine 官方仓库中的 bottom"
        if ! apk add --no-cache bottom; then
            warn "bottom 安装失败，请检查 Alpine 软件源和网络连接"
            return 1
        fi
    fi
    configure_bottom
}

install_fastfetch() {
    if package_is_installed fastfetch; then
        log "fastfetch 已安装，跳过重复安装"
        return 0
    fi

    log "安装 Alpine 官方仓库中的 fastfetch"
    if ! apk add --no-cache fastfetch; then
        warn "fastfetch 安装失败，请检查 Alpine 软件源和网络连接"
        return 1
    fi
}

run_fastfetch() {
    command -v fastfetch >/dev/null 2>&1 || {
        warn "未找到 fastfetch"
        return 1
    }

    fastfetch -s \
        title:os:kernel:host:board:bios:bootmgr:uptime:packages:shell:cpu:cpucache:gpu:opengl:opencl:vulkan:memory:physicalmemory:swap:disk:physicaldisk:btrfs:zpool:gamepad:display:wifi:localip:publicip:bluetoothradio:battery:poweradapter:loadavg:processes:dateTime:locale:camera:tpm:editor:command:colors:break
}

view_system_config() {
    if ! command -v fastfetch >/dev/null 2>&1; then
        log "未安装 fastfetch，先从 Alpine 官方仓库安装"
        if ! install_fastfetch; then
            return 1
        fi
    fi
    run_fastfetch
}

add_common_package() {
    common_number="$1"
    common_package="$2"
    common_description="$3"

    case " $common_selected_numbers " in
        *" $common_number "*)
            return
            ;;
    esac

    common_selected_numbers="$common_selected_numbers $common_number"
    case "$common_package" in
        bottom)
            common_bottom=1
            if package_is_installed bottom; then
                printf "  - %-10s\t%s" "bottom" "$common_description"
                print_status_column 48 17 "$common_description" "✅ 已安装"
            else
                printf "  - %-10s\t%s" "bottom" "$common_description"
                print_status_column 48 17 "$common_description" "⬜ 待安装"
            fi
            ;;
        fastfetch)
            common_fastfetch=1
            if package_is_installed fastfetch; then
                printf "  - %-10s\t%s" "fastfetch" "$common_description"
                print_status_column 48 17 "$common_description" "✅ 已安装"
            else
                printf "  - %-10s\t%s" "fastfetch" "$common_description"
                print_status_column 48 17 "$common_description" "⬜ 待安装"
            fi
            ;;
        *)
            if package_is_installed "$common_package"; then
                printf "  - %-10s\t%s" "$common_package" "$common_description"
                print_status_column 48 17 "$common_description" "✅ 已安装"
            else
                common_packages="$common_packages${common_packages:+ }$common_package"
                printf "  - %-10s\t%s" "$common_package" "$common_description"
                print_status_column 48 17 "$common_description" "⬜ 待安装"
            fi
            ;;
    esac
}

install_base_software() {
    printf "\n----------------------------------------\n"
    printf "基础软件\n"
    printf "----------------------------------------\n"
    print_package_item 1 curl "通过 HTTP/HTTPS 下载或调用接口" curl
    print_package_item 2 bash "功能更完整的 Shell" bash
    print_package_item 3 jq "在命令行解析和处理 JSON" jq
    print_package_item 4 wget "下载文件" wget
    print_package_item 5 git "Git 版本控制工具" git
    print_package_item 6 vim "终端文本编辑器" vim
    print_package_item 7 bottom "终端系统监控 (替代 htop)" bottom
    print_package_item 8 tmux "终端会话管理" tmux
    print_package_item 9 unzip "解压 ZIP 文件" unzip
    print_package_item 10 fastfetch "查看系统信息和硬件配置" fastfetch

    while :; do
        if [ "$ASSUME_YES" -eq 1 ]; then
            common_input="all"
            log "非交互模式，默认安装全部基础软件"
        else
            printf "请输入编号（空格或逗号分隔，输入 a 全选，0/q 返回，直接回车返回）: "
            read -r common_input || common_input=""
            if has_nonprintable_input "$common_input"; then
                continue
            fi
            if [ -z "$common_input" ]; then
                warn "已取消基础软件安装"
                return 2
            fi
            case "$common_input" in
                0|q|Q)
                    warn "已取消基础软件安装"
                    return 2
                    ;;
            esac
        fi

        case "$common_input" in
            all|ALL|a|A)
                common_choices="1 2 3 4 5 6 7 8 9 10"
                ;;
            *)
                case "$common_input" in
                    *[!0-9,\ ]*)
                        warn "编号只能包含数字、空格和逗号"
                        continue
                        ;;
                esac
                common_choices="$(printf '%s' "$common_input" | tr ',' ' ')"
                ;;
        esac

        common_selected_numbers=""
        common_packages=""
        common_bottom=0
        common_fastfetch=0
        common_invalid=0
        printf "\n本次处理清单（已安装项自动跳过）：\n"
        for common_choice in $common_choices; do
            case "$common_choice" in
                1) add_common_package 1 curl "通过 HTTP/HTTPS 下载或调用接口" ;;
                2) add_common_package 2 bash "功能更完整的 Shell" ;;
                3) add_common_package 3 jq "在命令行解析和处理 JSON" ;;
                4) add_common_package 4 wget "下载文件" ;;
                5) add_common_package 5 git "Git 版本控制工具" ;;
                6) add_common_package 6 vim "终端文本编辑器" ;;
                7) add_common_package 7 bottom "终端系统监控 (替代 htop)" ;;
                8) add_common_package 8 tmux "终端会话管理" ;;
                9) add_common_package 9 unzip "解压 ZIP 文件" ;;
                10) add_common_package 10 fastfetch "查看系统信息和硬件配置" ;;
                *)
                    warn "无效软件编号：$common_choice"
                    common_invalid=1
                    ;;
            esac
        done

        if [ "$common_invalid" -eq 0 ] && {
            [ -n "$common_packages" ] || [ "$common_bottom" -eq 1 ] || [ "$common_fastfetch" -eq 1 ];
        }; then
            break
        fi
        warn "请输入有效的软件编号"
    done

    if [ -n "$common_packages" ]; then
        if ! apk add --no-cache $common_packages; then
            warn "基础软件安装失败"
            return 1
        fi
    fi

    if [ -z "$common_packages" ] && [ "$common_bottom" -eq 0 ] && [ "$common_fastfetch" -eq 0 ]; then
        log "所选基础软件均已安装，无需重复安装"
    fi

    if [ "$common_bottom" -eq 1 ]; then
        if ! install_bottom; then
            return 1
        fi
    fi

    if [ "$common_fastfetch" -eq 1 ]; then
        if ! install_fastfetch; then
            return 1
        fi
        run_fastfetch
    fi
    log "基础软件安装完成"
}

configure_npm_pypi_mirrors() {
    if [ "$REGION" = "cn" ]; then
        if [ "$common_npm" -eq 1 ]; then
            if npm config set registry https://registry.npmmirror.com/; then
                log "npm 已配置为 npmmirror：https://registry.npmmirror.com/"
            else
                warn "npm 换源失败"
                return 1
            fi
        fi

        if [ "$common_pip3" -eq 1 ]; then
            if pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/; then
                log "pip3 已配置为阿里云 PyPI 源"
            else
                warn "pip3 换源失败"
                return 1
            fi
        fi
    else
        [ "$common_npm" -eq 1 ] && log "国外/海外环境，保留 npm 官方源"
        [ "$common_pip3" -eq 1 ] && log "国外/海外环境，保留 PyPI 官方源"
    fi
}

install_common_software() {
    printf "\n----------------------------------------\n"
    printf "常用软件\n"
    printf "----------------------------------------\n"
    print_package_item 1 npx "Node.js 包执行工具" npm
    print_package_item 2 pip3 "Python 3 包管理工具" py3-pip

    while :; do
        if [ "$ASSUME_YES" -eq 1 ]; then
            common_input="all"
            log "非交互模式，默认安装全部常用软件"
        else
            printf "请输入编号（空格或逗号分隔，输入 a 全选，0/q 返回，直接回车返回）: "
            read -r common_input || common_input=""
            if has_nonprintable_input "$common_input"; then
                continue
            fi
            if [ -z "$common_input" ]; then
                warn "已取消常用软件安装"
                return 2
            fi
            case "$common_input" in
                0|q|Q)
                    warn "已取消常用软件安装"
                    return 2
                    ;;
            esac
        fi

        case "$common_input" in
            all|ALL|a|A)
                common_choices="1 2"
                ;;
            *)
                case "$common_input" in
                    *[!0-9,\ ]*)
                        warn "编号只能包含数字、空格和逗号"
                        continue
                        ;;
                esac
                common_choices="$(printf '%s' "$common_input" | tr ',' ' ')"
                ;;
        esac

        common_packages=""
        common_npm=0
        common_pip3=0
        common_invalid=0
        printf "\n本次处理清单（已安装项自动跳过）：\n"
        for common_choice in $common_choices; do
            case "$common_choice" in
                1)
                    common_npm=1
                    if package_is_installed npm; then
                        printf "  - %-10s\t%s" "npx" "Node.js 包执行工具"
                        print_status_column 48 17 "Node.js 包执行工具" "✅ 已安装"
                    else
                        if [ -n "$common_packages" ]; then
                            common_packages="$common_packages npm"
                        else
                            common_packages="npm"
                        fi
                        printf "  - %-10s\t%s" "npx" "Node.js 包执行工具"
                        print_status_column 48 17 "Node.js 包执行工具" "⬜ 待安装"
                    fi
                    ;;
                2)
                    common_pip3=1
                    if package_is_installed py3-pip; then
                        printf "  - %-10s\t%s" "pip3" "Python 3 包管理工具"
                        print_status_column 48 17 "Python 3 包管理工具" "✅ 已安装"
                    else
                        if [ -n "$common_packages" ]; then
                            common_packages="$common_packages py3-pip"
                        else
                            common_packages="py3-pip"
                        fi
                        printf "  - %-10s\t%s" "pip3" "Python 3 包管理工具"
                        print_status_column 48 17 "Python 3 包管理工具" "⬜ 待安装"
                    fi
                    ;;
                *)
                    warn "无效软件编号：$common_choice"
                    common_invalid=1
                    ;;
            esac
        done

        if [ "$common_invalid" -eq 0 ] && {
            [ -n "$common_packages" ] || [ "$common_npm" -eq 1 ] || [ "$common_pip3" -eq 1 ];
        }; then
            break
        fi
        warn "请输入有效的软件编号"
    done

    if [ -n "$common_packages" ]; then
        if ! apk add --no-cache $common_packages; then
            warn "常用软件安装失败"
            return 1
        fi
    else
        log "所选常用软件均已安装，无需重复安装"
    fi

    if ! configure_npm_pypi_mirrors; then
        return 1
    fi
    log "常用软件处理完成"
}

fetch_latest_stable_release() {
    ensure_download_tools
    release_json="$(mktemp)"
    if ! curl -fsSL --max-time 20 https://alpinelinux.org/releases.json -o "$release_json"; then
        rm -f "$release_json"
        return 1
    fi

    latest_release="$(sed -n 's/.*"latest_stable":"\([^"]*\)".*/\1/p' "$release_json")"
    rm -f "$release_json"
    [ -n "$latest_release" ] || return 1
    printf '%s' "$latest_release"
}

kernel_package_candidates() {
    apk info 2>/dev/null | grep -E '^linux-(edge|lts|virt|stable|hardened)$' || true
}

latest_kernel_package_version() {
    apk policy "$1" 2>/dev/null | sed -n '/^[[:space:]][[:space:]]*[0-9][^:]*:/ { s/^[[:space:]]*//; s/:.*//; p; q; }'
}

installed_kernel_package_version() {
    installed_kernel="$(apk info -e -v "$1" 2>/dev/null || true)"
    printf '%s' "$installed_kernel" | sed "s/^$1-//"
}

upgrade_alpine_system() {
    log "检查 Alpine 内核和发行版更新"
    if ! apk update; then
        warn "apk 索引更新失败，未执行系统更新"
        return 1
    fi

    current_release="$(cat /etc/alpine-release)"
    current_branch="$(alpine_branch)"
    latest_stable_release="$(fetch_latest_stable_release || true)"
    kernel_packages="$(kernel_package_candidates)"

    printf "当前 Alpine 版本：%s（软件源：%s）\n" "$current_release" "$current_branch"
    if [ -n "$latest_stable_release" ]; then
        printf "官方最新稳定版：%s\n" "$latest_stable_release"
    else
        warn "无法获取官方最新稳定版信息"
    fi
    printf "当前运行内核：%s\n" "$(uname -r)"

    if [ -n "$kernel_packages" ]; then
        printf "内核包状态（运行中的内核与内核包版本可能不同）：\n"
        for kernel_package in $kernel_packages; do
            kernel_installed="$(installed_kernel_package_version "$kernel_package")"
            kernel_latest="$(latest_kernel_package_version "$kernel_package")"
            if [ -n "$kernel_installed" ]; then
                installed_display="$kernel_installed"
            else
                installed_display="未知"
            fi
            if [ -n "$kernel_latest" ]; then
                latest_display="$kernel_latest"
            else
                latest_display="未知"
            fi
            if [ -n "$kernel_latest" ] && [ "$kernel_installed" = "$kernel_latest" ]; then
                printf "  - %s: 已安装 %s（已是最新）\n" "$kernel_package" "$kernel_installed"
            else
                printf "  - %s: 已安装 %s，可用 %s\n" "$kernel_package" "$installed_display" "$latest_display"
            fi
        done
    else
        warn "未检测到 Alpine 官方内核包，可能处于容器或使用自定义内核"
    fi

    upgrade_mode=""
    target_release=""
    if [ "$ASSUME_YES" -eq 1 ]; then
        upgrade_mode="kernel"
        warn "非交互模式仅更新当前发行版的内核包，跳过跨发行版升级"
    elif [ "$current_branch" = "edge" ]; then
        printf "请选择更新方式：\n"
        printf "  1) 仅更新内核\n"
        printf "  2) 仅升级当前发行版\n"
        printf "  3) 更新内核并切换到最新稳定发行版（不支持自动从 edge 切换）\n"
        printf "  0) 取消\n"
        printf "请输入编号 [0/q]: "
        read -r upgrade_choice || upgrade_choice=""
        if has_nonprintable_input "$upgrade_choice"; then
            return 2
        fi
        case "${upgrade_choice:-0}" in
            1) upgrade_mode="kernel" ;;
            2) upgrade_mode="packages" ;;
            3) warn "当前为 edge，已取消跨发行版切换"; return 2 ;;
            0|q|Q) log "已取消系统升级"; return 2 ;;
            *) warn "无效选择：$upgrade_choice"; return 1 ;;
        esac
    else
        printf "请选择更新方式：\n"
        printf "  1) 仅更新内核\n"
        printf "  2) 仅升级当前发行版\n"
        if [ -n "$latest_stable_release" ]; then
            printf "  3) 更新内核并升级到最新稳定版（%s）\n" "$latest_stable_release"
        else
            printf "  3) 更新内核并升级到目标发行版\n"
        fi
        printf "  0) 取消\n"
        printf "请输入编号 [0/q]: "
        read -r upgrade_choice || upgrade_choice=""
        if has_nonprintable_input "$upgrade_choice"; then
            return 2
        fi
        case "${upgrade_choice:-0}" in
            1) upgrade_mode="kernel" ;;
            2) upgrade_mode="packages" ;;
            3) upgrade_mode="release" ;;
            0|q|Q) log "已取消系统升级"; return 2 ;;
            *) warn "无效选择：$upgrade_choice"; return 1 ;;
        esac

        if [ "$upgrade_mode" = "release" ]; then
            if [ -n "$latest_stable_release" ]; then
                target_release="$latest_stable_release"
            else
                printf "请输入目标发行版（例如 v3.24）: "
                read -r target_release || target_release=""
            fi
        fi
    fi

    if [ "$upgrade_mode" = "packages" ]; then
        if ! apk upgrade --available; then
            warn "当前发行版软件包升级失败"
            return 1
        fi
        log "当前 Alpine 发行版软件包升级完成"
        return 0
    fi

    if [ "$upgrade_mode" = "kernel" ]; then
        target_release=""
    fi

    if [ "$upgrade_mode" = "release" ] && [ -z "$target_release" ]; then
        warn "未指定目标发行版，已取消升级"
        return 1
    fi

    if [ "$upgrade_mode" = "release" ] && [ "$target_release" != "$current_branch" ]; then
        if ! printf '%s\n' "$target_release" | grep -Eq '^v[0-9]+\.[0-9]+$'; then
            warn "目标发行版格式无效，应为 v主版本.次版本，例如 v3.24"
            return 1
        fi

        current_version="${current_branch#v}"
        current_major="$(printf '%s' "$current_version" | cut -d. -f1)"
        current_minor="$(printf '%s' "$current_version" | cut -d. -f2)"
        target_version="${target_release#v}"
        target_major="$(printf '%s' "$target_version" | cut -d. -f1)"
        target_minor="$(printf '%s' "$target_version" | cut -d. -f2)"
        if [ "$target_major" -lt "$current_major" ] || { [ "$target_major" -eq "$current_major" ] && [ "$target_minor" -le "$current_minor" ]; }; then
            warn "目标版本必须高于当前版本 $current_branch"
            return 1
        fi

        release_repos="/etc/apk/repositories"
        if [ ! -f "$release_repos" ] || ! grep -Eq '/(v[0-9]+\.[0-9]+|edge)/(main|community|testing)([[:space:]]*)$' "$release_repos"; then
            warn "未识别到标准 Alpine 软件源，未修改发行版"
            return 1
        fi

        release_backup="$release_repos.bak.$(date +%Y%m%d%H%M%S)"
        cp "$release_repos" "$release_backup"
        log "已备份软件源到 $release_backup"
        sed -i -E "s#/(v[0-9]+\.[0-9]+|edge)/(main|community|testing)([[:space:]]*)$#/$target_release/\\2\\3#" "$release_repos"

        if ! apk update; then
            cp "$release_backup" "$release_repos"
            apk update || true
            warn "目标发行版软件源不可用，已恢复原软件源"
            return 1
        fi

        if ! apk upgrade --available; then
            warn "发行版软件包升级未完成，请检查输出后处理"
            return 1
        fi
        log "Alpine 已切换至 $target_release 软件源并完成升级；请重启以使用新内核"
        return 0
    fi

    if [ "$upgrade_mode" = "release" ]; then
        if ! apk upgrade --available; then
            warn "当前 Alpine 发行版软件包升级失败"
            return 1
        fi
        log "当前已是最新稳定发行版 $current_branch，软件包升级完成"
        return 0
    fi

    if [ -n "$kernel_packages" ]; then
        if ! apk upgrade --available $kernel_packages; then
            warn "Linux 内核更新失败"
            return 1
        fi
        log "内核更新完成；请在维护窗口重启后使用新内核"
    else
        warn "没有可更新的 Alpine 内核包"
    fi
}

current_timezone() {
    if [ -s /etc/timezone ]; then
        sed -n '1p' /etc/timezone
        return
    fi

    if [ -L /etc/localtime ] && command -v readlink >/dev/null 2>&1; then
        timezone_link="$(readlink /etc/localtime 2>/dev/null || true)"
        case "$timezone_link" in
            /usr/share/zoneinfo/*)
                printf '%s' "${timezone_link#/usr/share/zoneinfo/}"
                ;;
        esac
    fi
}

configure_timezone() {
    log "调整时区"
    if ! apk add --no-cache tzdata; then
        warn "tzdata 安装失败"
        return 1
    fi

    existing_timezone="$(current_timezone)"
    [ -n "$existing_timezone" ] || existing_timezone="UTC"
    printf "当前时区：%s\n" "$existing_timezone"

    if [ "$ASSUME_YES" -eq 1 ]; then
        selected_timezone="$existing_timezone"
        log "非交互模式，保留当前时区：$selected_timezone"
    else
        while :; do
            printf "请输入时区（例如 Asia/Shanghai、Asia/Tokyo、Europe/London、UTC，0/q 取消，直接回车取消）: "
            read -r selected_timezone || selected_timezone=""
            case "$selected_timezone" in
                0|q|Q)
                    warn "已取消时区调整"
                    return 2
                    ;;
            esac
            if [ -z "$selected_timezone" ]; then
                warn "已取消时区调整"
                return 2
            fi

            case "$selected_timezone" in
                /*|*..*|*' '*)
                    warn "时区格式无效"
                    continue
                    ;;
            esac

            if [ -f "/usr/share/zoneinfo/$selected_timezone" ]; then
                break
            fi
            warn "未找到时区：$selected_timezone"
        done
    fi

    if [ ! -f "/usr/share/zoneinfo/$selected_timezone" ]; then
        warn "未找到时区：$selected_timezone"
        return 1
    fi

    if [ -e /etc/localtime ] || [ -L /etc/localtime ]; then
        cp -a /etc/localtime "/etc/localtime.bak.$(date +%Y%m%d%H%M%S)" || true
    fi
    ln -sf "/usr/share/zoneinfo/$selected_timezone" /etc/localtime
    printf '%s\n' "$selected_timezone" > /etc/timezone
    log "时区已调整为：$selected_timezone"
    date '+%F %T %Z'
}

configure_hostname() {
    current_hostname="$(hostname)"
    log "调整主机名"
    printf "当前主机名：%s\n" "$current_hostname"

    if [ "$ASSUME_YES" -eq 1 ]; then
        warn "主机名需要手动输入，非交互模式已跳过"
        return 2
    fi

    while :; do
        printf "请输入新主机名（字母、数字、点和连字符，0/q 取消，直接回车取消）: "
        read -r selected_hostname || selected_hostname=""
        case "$selected_hostname" in
            0|q|Q)
                warn "已取消主机名调整"
                return 2
                ;;
        esac
        if [ -z "$selected_hostname" ]; then
            warn "已取消主机名调整"
            return 2
        fi

        case "$selected_hostname" in
            *[!A-Za-z0-9.-]*|.*|*.|*..*|-*|*-)
                warn "主机名格式无效"
                continue
                ;;
        esac
        break
    done

    if ! hostname "$selected_hostname"; then
        warn "无法设置运行时主机名：$selected_hostname"
        return 1
    fi

    if [ -f /etc/hostname ]; then
        cp /etc/hostname "/etc/hostname.bak.$(date +%Y%m%d%H%M%S)"
    fi
    printf '%s\n' "$selected_hostname" > /etc/hostname
    log "主机名已调整为：$selected_hostname"
}

enable_zswap() {
    log "开启 zswap"
    zswap_pool_percent="20"
    [ "$#" -gt 0 ] && zswap_pool_percent="$1"

    if ! awk 'NR > 1 { found=1 } END { exit found ? 0 : 1 }' /proc/swaps 2>/dev/null; then
        warn "当前没有启用任何 swap 后端；zswap 只是 swap 的压缩缓存，不会自行创建 swap"
        warn "如需使用 zswap，请先配置 swap 文件或 swap 分区"
    fi

    if [ -d /sys/module/zswap/parameters ]; then
        if [ -w /sys/module/zswap/parameters/enabled ]; then
            echo 1 > /sys/module/zswap/parameters/enabled || warn "当前系统不允许运行时开启 zswap"
        else
            warn "当前系统不允许运行时写入 zswap.enabled"
        fi

        if [ -w /sys/module/zswap/parameters/max_pool_percent ]; then
            echo "$zswap_pool_percent" > /sys/module/zswap/parameters/max_pool_percent || true
        fi
    else
        warn "当前内核未暴露 zswap 参数，可能需要内核支持或重启后通过启动参数启用"
    fi

    persist_kernel_option "zswap.enabled=1"
    persist_kernel_option "zswap.max_pool_percent=$zswap_pool_percent"
    log "zswap 配置完成；如本次未立即生效，请重启后检查"
    check_zswap

}
check_zswap() {
    log "检查 zswap 状态"

    if [ -d /sys/module/zswap/parameters ]; then
        enabled="unknown"
        max_pool="unknown"
        compressor="unknown"
        zpool="unknown"

        [ -r /sys/module/zswap/parameters/enabled ] && enabled="$(cat /sys/module/zswap/parameters/enabled)"
        [ -r /sys/module/zswap/parameters/max_pool_percent ] && max_pool="$(cat /sys/module/zswap/parameters/max_pool_percent)"
        [ -r /sys/module/zswap/parameters/compressor ] && compressor="$(cat /sys/module/zswap/parameters/compressor)"
        [ -r /sys/module/zswap/parameters/zpool ] && zpool="$(cat /sys/module/zswap/parameters/zpool)"

        case "$enabled" in
            Y|y|1) log "zswap 当前已启用" ;;
            N|n|0) warn "zswap 当前未启用，可能需要重启后由启动参数生效" ;;
            *) warn "zswap 当前启用状态未知：$enabled" ;;
        esac

        log "zswap max_pool_percent: $max_pool"
        log "zswap compressor: $compressor"
        log "zswap zpool: $zpool"
    else
        warn "未发现 /sys/module/zswap/parameters，当前内核可能未启用 zswap 支持"
    fi

    if grep -qw "zswap.enabled=1" /proc/cmdline 2>/dev/null; then
        log "当前内核启动参数已包含 zswap.enabled=1"
    else
        warn "当前 /proc/cmdline 未包含 zswap.enabled=1；如已写入启动配置，需重启后生效"
    fi

    if grep -Fq "zswap.enabled=1" /etc/update-extlinux.conf 2>/dev/null || grep -Fq "zswap.enabled=1" /etc/default/grub 2>/dev/null; then
        log "启动配置中已写入 zswap.enabled=1"
    else
        warn "未在 extlinux/grub 配置中检测到 zswap.enabled=1"
    fi
}

show_swap_zswap_status() {
    log "检查 Swap / zswap 状态"

    if awk 'NR > 1 { found=1 } END { exit found ? 0 : 1 }' /proc/swaps 2>/dev/null; then
        printf "当前 Swap：\n"
        cat /proc/swaps
    else
        warn "当前没有启用任何 Swap 后端"
    fi
    free -h
    check_zswap
}

configure_swap_file() {
    swap_file="/swapfile"

    if grep -q "^$swap_file[[:space:]]" /proc/swaps 2>/dev/null; then
        warn "$swap_file 当前正在使用，不能直接覆盖"
        return 1
    fi

    if [ -e "$swap_file" ]; then
        warn "$swap_file 已存在，将在确认后重新创建"
        if [ "$ASSUME_YES" -eq 1 ]; then
            warn "自动模式不覆盖已有 swap 文件"
            return 0
        fi
        printf "是否重新创建 $swap_file？输入 y 继续，直接回车取消: "
        read -r recreate_swap || recreate_swap=""
        if [ "$recreate_swap" != "y" ] && [ "$recreate_swap" != "Y" ]; then
            warn "已取消重新创建 swap 文件"
            return 0
        fi
    fi

    if [ "$ASSUME_YES" -eq 1 ]; then
        swap_size_mb="2048"
        log "自动模式使用默认 Swap 大小：$swap_size_mb MiB"
    else
        printf "请输入 Swap 大小（MiB，直接回车使用 2048）: "
        read -r swap_size_mb || swap_size_mb=""
        if [ -z "$swap_size_mb" ]; then
            swap_size_mb="2048"
        fi
    fi

    case "$swap_size_mb" in
        ''|*[!0-9]*|0)
            warn "Swap 大小必须是大于 0 的整数 MiB"
            return 1
            ;;
    esac

    log "创建 $swap_size_mb MiB Swap 文件：$swap_file"
    if ! dd if=/dev/zero of="$swap_file" bs=1M count="$swap_size_mb" >/dev/null 2>&1; then
        warn "Swap 文件创建失败"
        return 1
    fi
    chmod 600 "$swap_file"
    if ! mkswap "$swap_file" >/dev/null; then
        warn "mkswap 执行失败"
        return 1
    fi
    if ! swapon "$swap_file"; then
        warn "Swap 文件启用失败"
        return 1
    fi

    if [ ! -f /etc/fstab ] || ! grep -q "^$swap_file[[:space:]]" /etc/fstab; then
        printf "%s none swap sw 0 0\n" "$swap_file" >> /etc/fstab
        log "已将 $swap_file 写入 /etc/fstab"
    fi
    log "Swap 文件已创建并启用"
    free -h
}

configure_swap_zswap() {
    if [ "$ASSUME_YES" -eq 1 ]; then
        enable_zswap
        show_swap_zswap_status
        return
    fi

    while :; do
        printf "\nSwap / zswap 配置：\n"
        printf "  1) 创建或重新配置 Swap 文件\n"
        printf "  2) 开启并配置 zswap\n"
        printf "  3) 查看当前状态\n"
        printf "  0) 返回主菜单\n"
        printf "请输入编号（0/q 返回）: "
        read -r swap_action || swap_action="0"
        if has_nonprintable_input "$swap_action"; then
            continue
        fi
        case "$swap_action" in
            1)
                configure_swap_file
                ;;
            2)
                current_pool="20"
                [ -r /sys/module/zswap/parameters/max_pool_percent ] && current_pool="$(cat /sys/module/zswap/parameters/max_pool_percent)"
                printf "zswap 缓存占内存比例（当前 %s%%，直接回车保留）: " "$current_pool"
                read -r selected_pool || selected_pool=""
                if [ -z "$selected_pool" ]; then
                    selected_pool="$current_pool"
                fi
                case "$selected_pool" in
                    ''|*[!0-9]*|0)
                        warn "缓存比例必须是 1-100 的整数"
                        continue
                        ;;
                esac
                if [ "$selected_pool" -gt 100 ]; then
                    warn "缓存比例不能超过 100"
                    continue
                fi
                enable_zswap "$selected_pool"
                ;;
            3)
                show_swap_zswap_status
                ;;
            0|q|Q)
                return 2
                ;;
            *)
                warn "无效功能编号：$swap_action"
                ;;
        esac
    done
}


enable_tun() {
    log "启用 tun 内核模块"

    if ! command -v modprobe >/dev/null 2>&1; then
        log "未找到 modprobe，安装 kmod"
        if ! apk add --no-cache kmod; then
            warn "kmod 安装失败，无法自动加载 tun 模块"
        fi
    fi

    if command -v modprobe >/dev/null 2>&1; then
        if modprobe tun >/dev/null 2>&1; then
            log "tun 内核模块已加载或已内建"
        else
            warn "加载 tun 内核模块失败，当前内核可能未提供 tun 支持"
        fi
    fi

    modules_file="/etc/modules"
    if [ ! -f "$modules_file" ]; then
        touch "$modules_file"
    fi

    if grep -Eq "^[[:space:]]*tun([[:space:]]|$)" "$modules_file"; then
        log "tun 已存在于 $modules_file"
    else
        echo tun >> "$modules_file"
        log "已将 tun 写入 $modules_file，重启后自动加载"
    fi

    if command -v rc-update >/dev/null 2>&1; then
        if rc-update add modules boot >/dev/null 2>&1; then
            log "已启用 OpenRC modules 服务"
        else
            warn "无法启用 OpenRC modules 服务，请检查 rc-update 输出"
        fi
    fi

    check_tun
}

check_tun() {
    log "检查 tun 状态"

    if [ -d /sys/module/tun ] || grep -q "^tun " /proc/modules 2>/dev/null; then
        log "tun 内核模块当前已加载"
    else
        warn "tun 内核模块当前未加载"
    fi

    if [ -c /dev/net/tun ]; then
        log "TUN 设备节点可用：/dev/net/tun"
    else
        warn "未发现 /dev/net/tun，容器或 VPN 程序可能无法使用 TUN"
    fi
}

persist_kernel_option() {
    opt="$1"
    persisted=0

    persist_file() {
        file="$1"
        key="$2"

        if grep -Fq "$opt" "$file"; then
            return
        fi

        cp "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"

        if grep -q "^${key}=.*\"$" "$file"; then
            sed -i "/^${key}=/ s/\"$/ ${opt}\"/" "$file"
        elif grep -q "^${key}=" "$file"; then
            sed -i "/^${key}=/ s/$/ ${opt}/" "$file"
        else
            printf "%s=\"%s\"\n" "$key" "$opt" >> "$file"
        fi
    }

    if [ -f /etc/update-extlinux.conf ]; then
        persisted=1
        persist_file /etc/update-extlinux.conf default_kernel_opts
        if command -v update-extlinux >/dev/null 2>&1; then
            update-extlinux >/dev/null 2>&1 || warn "update-extlinux 执行失败，请手动检查启动项"
        fi
    fi

    if [ -f /etc/default/grub ]; then
        persisted=1
        persist_file /etc/default/grub GRUB_CMDLINE_LINUX_DEFAULT
        if command -v update-grub >/dev/null 2>&1; then
            update-grub >/dev/null 2>&1 || warn "update-grub 执行失败，请手动检查启动项"
        elif command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
            grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || warn "grub-mkconfig 执行失败，请手动检查启动项"
        fi
    fi

    if [ "$persisted" -eq 0 ]; then
        warn "未找到 extlinux/grub 配置文件，无法自动持久化 $opt"
    fi
}

root_has_password() {
    shadow_line="$(grep "^root:" /etc/shadow 2>/dev/null || true)"
    hash="$(printf "%s" "$shadow_line" | cut -d: -f2)"

    [ -n "$hash" ] || return 1
    [ "$hash" = "x" ] && return 1

    case "$hash" in
        !*) return 1 ;;
        \**) return 1 ;;
    esac

    return 0
}

root_has_authorized_key() {
    [ -s /root/.ssh/authorized_keys ] && grep -v "^[[:space:]]*$" /root/.ssh/authorized_keys | grep -vq "^[[:space:]]*#"
}

setup_ssh_login() {
    log "安装并配置 OpenSSH"
    apk update >/dev/null 2>&1 || true
    apk add --no-cache openssh

    existing_key=0
    existing_pass=0
    root_has_authorized_key && existing_key=1
    root_has_password && existing_pass=1

    printf "\n当前 root 登录凭证检测：\n"
    if [ "$existing_key" -eq 1 ]; then
        key_count="$(grep -v "^[[:space:]]*$" /root/.ssh/authorized_keys | grep -vc "^[[:space:]]*#" || true)"
        log "已存在 SSH 公钥：${key_count} 条"
    else
        warn "未检测到 root SSH 公钥"
    fi

    if [ "$existing_pass" -eq 1 ]; then
        log "root 密码已设置"
    else
        warn "root 密码未设置或已锁定"
    fi

    mkdir -p /etc/ssh
    [ -f /etc/ssh/sshd_config ] || touch /etc/ssh/sshd_config
    ssh_config_changed=0
    credentials_changed=0

    ssh-keygen -A >/dev/null 2>&1 || true

    tmp_config="$(mktemp)"
    {
        printf "PermitRootLogin yes\n"
        printf "PasswordAuthentication yes\n"
        printf "PubkeyAuthentication yes\n"
        grep -viE "^[#[:space:]]*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)[[:space:]]" /etc/ssh/sshd_config || true
    } > "$tmp_config"
    if command -v sshd >/dev/null 2>&1 && ! sshd -t -f "$tmp_config"; then
        rm -f "$tmp_config"
        warn "生成的 SSH 配置校验失败，未修改 sshd_config"
        return 1
    fi
    if cmp -s "$tmp_config" /etc/ssh/sshd_config; then
        rm -f "$tmp_config"
        log "SSH 登录策略已符合要求，未修改 sshd_config"
    else
        cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
        mv "$tmp_config" /etc/ssh/sshd_config
        ssh_config_changed=1
        log "已更新 SSH 登录策略"
    fi

    setup_key="$existing_key"
    setup_pass="$existing_pass"
    while :; do
        if [ "$setup_key" -eq 1 ]; then
            printf "\n已检测到 SSH 公钥，是否追加新的公钥？输入 y 追加，直接回车跳过: "
            read -r add_key
            if [ "$add_key" = "y" ] || [ "$add_key" = "Y" ]; then
                printf "请粘贴新的 SSH 公钥: "
                read -r ssh_key
            else
                ssh_key=""
                warn "保留现有 SSH 公钥"
            fi
        else
            printf "\n未检测到 SSH 公钥，请粘贴你的 SSH 公钥，直接回车跳过: "
            read -r ssh_key
        fi

        if [ -n "$ssh_key" ]; then
            mkdir -p /root/.ssh
            chmod 700 /root/.ssh
            if grep -Fqx "$ssh_key" /root/.ssh/authorized_keys 2>/dev/null; then
                warn "该公钥已存在，未重复追加"
            else
                printf "%s\n" "$ssh_key" >> /root/.ssh/authorized_keys
                log "公钥已保存到 /root/.ssh/authorized_keys"
                credentials_changed=1
            fi
            chmod 600 /root/.ssh/authorized_keys
            setup_key=1
        elif [ "$setup_key" -eq 0 ]; then
            warn "已跳过公钥设置"
        fi

        if [ "$setup_pass" -eq 1 ]; then
            printf "是否修改 root 密码？输入 y 修改，直接回车跳过: "
        else
            printf "是否设置 root 密码？输入 y 设置，直接回车跳过: "
        fi
        read -r set_pass
        if [ "$set_pass" = "y" ] || [ "$set_pass" = "Y" ]; then
            if passwd root; then
                setup_pass=1
                credentials_changed=1
            else
                warn "root 密码未修改"
            fi
        else
            warn "已跳过 root 密码设置"
        fi

        if [ "$setup_key" -eq 1 ] || [ "$setup_pass" -eq 1 ]; then
            break
        fi
        warn "密码和密钥必须至少配置一个，请重新输入"
    done

    rc-update add sshd default >/dev/null 2>&1 || true
    if command -v rc-service >/dev/null 2>&1; then
        if [ "$ssh_config_changed" -eq 1 ] || [ "$credentials_changed" -eq 1 ]; then
            rc-service sshd restart
            log "SSH 配置或凭证已变更，已重启 sshd"
        elif rc-service sshd status >/dev/null 2>&1; then
            log "SSH 配置和凭证均未变更，sshd 无需重启"
        else
            rc-service sshd start
            log "sshd 原本未运行，已启动服务"
        fi
    else
        if [ "$ssh_config_changed" -eq 1 ] || [ "$credentials_changed" -eq 1 ]; then
            service sshd restart
            log "SSH 配置或凭证已变更，已重启 sshd"
        else
            log "SSH 配置和凭证均未变更，未重启 sshd"
        fi
    fi

    log "SSH 配置完成：Root 登录、密码登录、密钥登录均已开启"
}

reboot_server() {
    printf "即将重启服务器，确认请输入 y: "
    read -r confirm_reboot || confirm_reboot=""
    if [ "$confirm_reboot" = "y" ] || [ "$confirm_reboot" = "Y" ]; then
        log "正在重启服务器"
        reboot
    else
        warn "已取消重启"
        return 2
    fi
}


execute_action() {
    action="$1"

    case "$action" in
        1)
            if [ "$SKIP_LINUX_MIRROR" -eq 1 ]; then
                warn "按参数跳过：更换 Alpine 软件源"
            else
                run_linuxmirrors
            fi
            ;;
        2)
            setup_ssh_login
            ;;
        3)
            configure_swap_zswap
            ;;
        4)
            update_apk_index
            ;;
        5)
            if [ "$SKIP_UPGRADE" -eq 1 ]; then
                warn "按参数跳过：升级已安装软件包"
            else
                upgrade_system
            fi
            ;;
        6)
            upgrade_alpine_system
            ;;
        7)
            install_base_software
            ;;
        8)
            install_common_software
            ;;
        9)
            enable_tun
            ;;
        10)
            if [ "$SKIP_DOCKER" -eq 1 ]; then
                warn "按参数跳过：安装 Docker / Compose"
            else
                install_docker
            fi
            ;;
        11)
            if [ "$SKIP_DOCKER" -eq 1 ]; then
                warn "按参数跳过：配置 Docker 镜像加速"
            else
                write_docker_daemon_config
                detect_docker_mirror
            fi
            ;;
        12)
            if [ "$SKIP_DOCKER" -eq 1 ]; then
                warn "按参数跳过：管理 Docker 容器"
            else
                manage_docker_containers
            fi
            ;;
        13)
            view_system_config
            ;;
        14)
            configure_timezone
            ;;
        15)
            configure_hostname
            ;;
        16)
            reboot_server
            ;;
        *)
            warn "无效功能编号：$action"
            ;;
    esac
}

run_all_actions() {
    for action in 1 4 5 6 7 8 9 10 11 14; do
        execute_action "$action"
    done
    warn "SSH、Swap / zswap、Docker 容器管理、时区、主机名和重启需要交互输入，自动模式已跳过第 2、3、12、14、15、16 项"
}

pause_before_menu() {
    printf "\n按回车返回功能菜单..."
    read -r _pause_input || true
}

menu_loop() {
    while :; do
        read_action
        case "$ACTION" in
            "")
                warn "请输入功能编号，输入 0 退出"
                ;;
            __ignore__)
                ;;
            0)
                log "退出初始化菜单"
                break
                ;;
            1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16)
                if execute_action "$ACTION"; then
                    action_status=0
                else
                    action_status=$?
                fi
                case "$action_status" in
                    0)
                        log "任务执行结束，返回菜单"
                        pause_before_menu
                        ;;
                    2)
                        log "操作已取消，返回菜单"
                        ;;
                    *)
                        warn "任务执行失败，返回菜单"
                        pause_before_menu
                        ;;
                esac
                ;;
            *)
                warn "无效功能编号：$ACTION"
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    ask_region
    normalize_region
    check_root_and_os

    log "Alpine 服务器初始化，环境：$REGION"

    if [ "$ASSUME_YES" -eq 1 ]; then
        run_all_actions
    else
        menu_loop
    fi

    log "已结束初始化脚本"
}

main "$@"
