#!/bin/bash

# 默认参数值
auto_install=false
interactive_install=false
use_root=false
use_current_user=false
specified_user=""
install_daemon=true
install_web=true
generate_service=true
install_node=true
node_version="v14.19.1"

# 常量定义
DEFAULT_MCSMANAGER_INSTALL_PATH="/opt/mcsmanager"

# 函数定义，用于显示帮助信息
display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -a, --auto                 Auto-install without user interaction."
  echo "  -i, --interactive          Interactive installation (default)."
  echo "  -r, --root                 Install as root (requires root privileges)."
  echo "      --user                 Install as the current user."
  echo "      --user=user            Install as the specified user (requires root privileges)."
  echo "      --no-daemon            Do not install daemon."
  echo "      --no-web               Do not install web."
  echo "      --no-service           Do not generate systemd service files."
  echo "      --no-node              Do not install Node.js."
  echo "      --directory=directory  Set MCSM installation directory."
  echo "      --daemon_directory=directory  Set daemon installation directory."
  echo "      --web_directory=directory     Set web installation directory."
  echo "      --node_directory=directory    Set Node.js installation directory."
  echo "      --node_version=version        Set Node.js version to install (default: v14.19.1)."
  echo "  -h, --help                 Display this help message."
  exit 0
}

# 解析命令行参数
while [ $# -gt 0 ]; do
  case "$1" in
    -a|--auto)
      auto_install=true
      interactive_install=false
      ;;
    -i|--interactive)
      interactive_install=true
      auto_install=false
      ;;
    -r|--root)
      use_root=true
      use_current_user=false
      specified_user=""
      ;;
    --user)
      use_current_user=true
      use_root=false
      specified_user=""
      ;;
    --user=*)
      use_current_user=false
      use_root=true
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
    -h|--help)
      display_help
      ;;
    *)
      echo "Invalid option: $1. Use -h or --help for help."
      exit 1
      ;;
  esac
  shift
done

# 检查是否以root用户运行，如果没有，显示错误信息并退出
if [ "$EUID" -ne 0 ] && [ "$use_root" = true ]; then
  echo -e "\033[31mYou need root privileges to install as root. Please use sudo or run as root.\033[0m"
  exit 1
fi

# 如果以其他用户安装，检查是否提供了指定的用户
if [ "$use_root" = true ] && [ -z "$specified_user" ]; then
  echo -e "\033[31mPlease specify a user using the --user=user option when installing as a different user.\033[0m"
  exit 1
fi

# 如果以其他用户安装，检查指定的用户是否存在
if [ "$use_root" = true ] && [ -n "$specified_user" ] && ! id "$specified_user" &>/dev/null; then
  echo -e "\033[31mThe specified user '$specified_user' does not exist.\033[0m"
  exit 1
fi

# 如果自动安装参数为true，不显示交互式信息
if [ "$auto_install" = true ]; then
  interactive_install=false
fi


# 检查是否提供了daemon_install_path参数，如果没有，使用mcsmanager_install_path，否则使用常量
if [ -z "$daemon_install_path" ]; then
  if [ -z "$mcsmanager_install_path" ]; then
    web_install_path="$mcsmanager_install_path/daemon"
  else
    if [ "$use_current_user" = true ]; then
      daemon_install_path="$HOME/mcsmanager/daemon"
    else
      daemon_install_path="$DEFAULT_DAEMON_INSTALL_PATH"
    fi
  fi
fi

# 检查是否提供了web_install_path参数，如果没有，使用mcsmanager_install_path，否则使用常量
if [ -z "$web_install_path" ]; then
  if [ -z "$mcsmanager_install_path" ]; then
    web_install_path="$mcsmanager_install_path/web"
  else
    if [ "$use_current_user" = true ]; then
      web_install_path="$HOME/mcsmanager/web"
    else
      web_install_path="$DEFAULT_WEB_INSTALL_PATH"
    fi
  fi
fi
