#!/bin/env bash

# 常量定义
DEFAULT_MCSMANAGER_INSTALL_PATH="/opt/mcsmanager"
DEFAULT_DAEMON_INSTALL_PATH="$DEFAULT_MCSMANAGER_INSTALL_PATH/daemon"
DEFAULT_WEB_INSTALL_PATH="$DEFAULT_MCSMANAGER_INSTALL_PATH/web"
DEFAULT_NODE_VERSION="v14.19.1"

# 默认参数值
auto_install=false
interactive_install=false
all_users=false
single_user=false
current_user=false
specified_user=""
install_daemon=true
install_web=true
generate_service=true
install_node=true
node_version=""

# 函数定义，检查是否以root用户运行，如果没有，显示错误信息并退出
checkroot() {
  if [ "$EUID" -ne 0 ] && { [ "$all_users" = true ] || { [ "$single_user" = true ] && [ "$specified_user" != "$USER" ]; }; }; then
    echo -e "\033[31m需要root权限才能以root或不同用户身份安装。\033[0m"
    exit 1
  fi
}

# 子函数，获取交互式安装信息
function interactive_install() {
  # 定义子程序，获取选项
  # read_with_options() 函数用于从一组选项中选择一个选项
  # 参数:
  #   $1: 要显示给用户的内容
  #   $2: 以竖线 "|" 分隔的选项列表字符串
  #   $3: 默认选项的编号 (从1开始)
  #   $4: 用户选择的结果将赋给这个传入的变量
    read_with_options() {
        local content="$1"
        local options="$2"
        local default_choice="$3"
        local option_array
        local -n user_choice="$4"

        # 将选项列表拆分为数组
        IFS="|" read -ra option_array <<<"$options"

        # 初始化编号
        local option_number=1

        # 构建选项字符串
        local options_string=""
        for option in "${option_array[@]}"; do
            local option_label="$option_number. $option"
            if [ "$option_number" -eq "$default_choice" ]; then
                option_label="$option_label (默认)"
            fi
            options_string="$options_string$option_label  "
            ((option_number++))
        done

        # 循环读取用户输入，直到输入正确的选项
        while true; do
            echo "$content" # 在循环内显示内容

            # 打印可用选项
            echo "$options_string"

            # 读取用户输入
            read -r user_choice

            # 如果用户输入为空值，则选择默认值
            if [ -z "$user_choice" ]; then
                user_choice="${option_array[$((default_choice - 1))]}"
                return 0
            fi

            # 检查用户输入是否有效
            if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#option_array[@]}" ]; then
                return 0
            else
                echo "无效的选项，请重新选择。"
            fi
        done
    }

    # 定义子程序，获取yes或no
    read_yes_or_no() {
        local prompt="$1"
        local user_input

        # 循环读取用户输入，直到输入有效的选项
        while true; do
      echo -n "$prompt (yes/no): "
            read -r user_input

            case "$user_input" in
      "yes" | "Yes" | "YES" | "y" | "Y")
        echo "您选择了: yes"
                return 0
                ;;
      "no" | "No" | "NO" | "n" | "N")
        echo "您选择了: no"
                return 1
                ;;
            *)
        echo "无效的选项，请输入 'yes'或'no'。"
                ;;
            esac
        done
    }

    # 定义子程序，获取非空返回值
    read_non_empty() {
        local prompt="$1"
        local -n result="$2" # 使用引用传递的方式将结果返回

        while true; do
            read -rp "$prompt" result

            # 检查输入是否为空
            if [ -n "$result" ]; then
                return 0
            else
                echo "输入不能为空，请重新输入。"
            fi
        done
    }

    local option_choice
    read_with_options "以哪个用户身份安装？" '所有用户|当前用户|root用户|指定用户' 2 option_choice
    case "${option_choice}" in
        1) # 所有用户
            all_users=true
            current_user=false
            ;;
        2) # 当前用户
            current_user=true
            all_users=false
            specified_user=$USER
            ;;
        3) # root用户
            current_user=true
            all_users=false
            specified_user="$(id -un 0)"
            ;;
        4) # 指定用户
            current_user=true
            all_users=false
            read_non_empty "请指定要使用的用户：" specified_user
            ;;
    esac
    read_with_options "安装哪些组件？" '所有用户|当前用户|root用户|指定用户' 2 option_choice
}

# 函数定义，用于显示帮助信息
display_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -A, --auto                 自动安装，无需用户交互。"
    echo "  -i, --interactive          交互式安装 (默认)。"
    echo "  -a, --all-users            为所有用户安装 (需要root权限)。"
    echo "      --user                 以当前用户身份安装。"
    echo "      --user=user            以指定用户身份安装 (需要root权限)。"
    echo "      --no-daemon            不安装守护程序。"
    echo "      --no-web               不安装Web组件。"
    echo "      --no-service           不生成systemd服务文件。"
    echo "      --no-node              不安装Node.js。"
    echo "      --directory=目录        设置MCSM安装目录。"
    echo "      --daemon_directory=目录 设置守护程序安装目录。"
    echo "      --web_directory=目录    设置Web组件安装目录。"
    echo "      --node_directory=目录   设置Node.js安装目录。"
    echo "      --node_version=版本     设置要安装的Node.js版本 (默认: v14.19.1)。"
    echo "  -h, --help                 显示帮助信息。"
    exit 0
}

# 解析命令行参数
while [ $# -gt 0 ]; do
    case "$1" in
    -A | --auto)
        auto_install=true
        interactive_install=false
        ;;
    -i | --interactive)
        interactive_install=true
        auto_install=false
        ;;
    -a | --all-users)
        all_users=true
        current_user=false
        specified_user=""
        ;;
    --user)
        current_user=true
        single_user=true
        specified_user=""
        ;;
    --user=*)
        current_user=false
        single_user=true
        specified_user="${1#*=}"
        ;;
    --no-daemon)
        install_daemon=false
        ;;
    --no-web)
        install_web=false
        ;;
    --no-service)
        generate_service=false
        ;;
    --no-node)
        install_node=false
        ;;
    --directory=*)
        mcsmanager_install_path="${1#*=}"
        ;;
    --daemon_directory=*)
        daemon_install_path="${1#*=}"
        ;;
    --web_directory=*)
        web_install_path="${1#*=}"
        ;;
    --node_directory=*)
        node_install_path="${1#*=}"
        ;;
    --node_version=*)
        node_version="${1#*=}"
        ;;
    -h | --help)
        display_help
        ;;
    *)
        echo "无效的选项: $1。使用 -h 或 --help 查看帮助。"
        exit 1
        ;;
    esac
    shift
done

checkroot

# 如果自动安装参数为true，不显示交互式信息
if [ "$auto_install" = true ]; then
    interactive_install=false
else
    interactive_install
fi

# 检查是否提供了daemon_install_path参数。如果没有，检查是否提供了mcsmanager_install_path。如果没有，选择使用常量。
if [ -z "$daemon_install_path" ]; then
    if [ -z "$mcsmanager_install_path" ]; then
        web_install_path="$mcsmanager_install_path/daemon"
    else
        if [ "$current_user" = true ]; then
            daemon_install_path="$HOME/mcsmanager/daemon"
        else
            daemon_install_path="$DEFAULT_DAEMON_INSTALL_PATH"
        fi
    fi
fi

# 检查是否提供了web_install_path参数。如果没有，检查是否提供了mcsmanager_install_path。如果没有，选择使用常量。
if [ -z "$web_install_path" ]; then
    if [ -z "$mcsmanager_install_path" ]; then
        web_install_path="$mcsmanager_install_path/web"
    else
        if [ "$current_user" = true ]; then
            web_install_path="$HOME/mcsmanager/web"
        else
            web_install_path="$DEFAULT_WEB_INSTALL_PATH"
        fi
    fi
fi

# 检查是否提供了node_version参数，如果没有，使用常量。
if [ -z "$node_version" ]; then
    node_version="$DEFAULT_NODE_VERSION"
fi
