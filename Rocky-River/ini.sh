#!/bin/sh
# OHPC官方可以参考的脚本和输入文件需要：
# yum -y install docs-ohpc
# 路径 /opt/ohpc/pub/doc/recipes/rocky8 下，有input.local
# /opt/ohpc/pub/doc/recipes/rocky8/x86_64/xcat/slurm/ 下有Install_guide.pdf  recipe.sh 可以作为参考

#iso_name="Rocky-8.10-x86_64-dvd1.iso"
iso_name="Rocky-9.6-x86_64-dvd.iso"
echo "计算节点系统镜像为 ${iso_name}"

# 初始化日志目录
LOG_DIR="ins_logs"
INSTALL_SCRIPT="Install.sh"
ENV_FILE="env.text"

# 清理旧的配置文件
if [ -e "$ENV_FILE" ]; then
    rm -f "$ENV_FILE"
fi

# 创建日志目录并清理旧日志
mkdir -p "$LOG_DIR"
mv *.sh.log "$LOG_DIR" 2>/dev/null

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# 检查日期并提示用户确认
check_date() {
    current_date=$(date +"%Y-%m-%d %H:%M:%S")
    echo ""
    echo "请确认当前系统时间是否正确："
    echo "当前时间: ${current_date}"
    read -p "是否继续执行？(y/n): " choice
    case "$choice" in
        y|Y ) log_info "用户确认时间正确，继续执行。";;
        n|N ) log_error "用户取消执行，脚本终止。";;
        * ) log_error "无效输入，脚本终止。";;
    esac
}

# 检查脚本文件权限与完整性
check_function_files() {
    local filelist=(
        reg_network.sh
        set_headnode.sh
        setup_clustershell.sh
        setup_devtools.sh
        setup_monitor.sh
        setup_network.sh
        setup_nfs.sh
        setup_nis.sh
        setup_ntp.sh
        setup_ohpc_xcat.sh
        setup_slurm.sh
        setup_sql.sh
        user_define.sh
    )

    for file in "${filelist[@]}"; do
        if [ ! -e "./functions/$file" ]; then
            log_error "$file 文件不存在!!!"
        fi
    done

    chmod +x ./functions/*.sh
    log_info "功能脚本权限检查完成"
}

# 寻找安装包文件的位置并判断其完整性
check_package_files() {
    ./functions/findpackage.sh "$iso_name"
    if [ $? -ne 0 ]; then
        log_error "安装包文件检查失败"
    fi
    log_info "安装包文件检查完成"
}

# 设置环境变量，生成 env.text 文件
generate_env_file() {
    ./functions/reg_name.sh
    ./functions/reg_network.sh

    # mysql root 密码
    mysql_root_password=$(openssl rand -base64 12)
    # 将密码写入环境变量文件
    echo "## MariaDB root 密码：" >>env.text
    echo "export mysql_root_pw=${mysql_root_password}" >>env.text

    # slurmdb 密码
    slurmdb_password=$(openssl rand -base64 12)
    echo "## SlurmDBD 密码：" >>env.text
    echo "export slurmdb_pw=${slurmdb_password}" >>env.text

    # xcat root 密码
    xcat_root_password=$(openssl rand -base64 12)
    # 将密码写入环境变量文件
    echo "## xCAT root 密码：" >>env.text
    echo "export xcat_root_pw=${xcat_root_password}" >>env.text
    log_info "MariaDB root / SlurmDBD / xCAT root 密码已生成"

    log_info "环境变量文件 env.text 生成完成"
}

# 生成 Install.sh 脚本
generate_install_script() {
    cat <<'EOF' >"$INSTALL_SCRIPT"
#!/bin/sh

if [ ! -e "./env.text" ]; then
    echo "错误：安装环境变量文件 env.text 未产生！"
    exit 10
else
    source "./env.text"
fi

# 定义标记文件目录
MARKER_DIR=".install_markers"
mkdir -p "$MARKER_DIR"

# 定义日志文件目录
LOG_DIR=".install_logs"
mkdir -p "$LOG_DIR"

# 定义标记函数
step_marker() {
    local step_name="$1"
    touch "$MARKER_DIR/$step_name"
}

# 检查步骤是否已经执行
should_skip_step() {
    local step_name="$1"
    [ -f "$MARKER_DIR/$step_name" ]
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# 错误处理函数
handle_error() {
    log_error "步骤 $current_step 失败，脚本停止。"
}

# 定义步骤执行函数
run_step() {
    local step_name="$1"
    local step_command="$2"

    current_step="$step_name"
    if should_skip_step "$step_name"; then
        log_info "跳过步骤: $step_name (已经执行过)"
        return 0
    fi

    log_info "开始执行步骤: $step_name -> -> ->"
    eval "$step_command"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        step_marker "$step_name"
        log_info "步骤完成: $step_name <- <- <-"
        echo ""
    else
        log_error "步骤失败: $step_name"
        return $exit_code
    fi
}

# 错误时执行处理函数
trap 'handle_error' ERR

set -e

# 执行安装步骤
run_step "make_repo" "./functions/make_repo.sh"
run_step "set_headnode" "./functions/set_headnode.sh"
run_step "setup_network" "./functions/setup_network.sh"
run_step "setup_ntp" "./functions/setup_ntp.sh"
run_step "setup_sql" "./functions/setup_sql.sh"
run_step "setup_ohpc_xcat" "./functions/setup_ohpc_xcat.sh"
run_step "setup_slurm" "./functions/setup_slurm.sh"
run_step "setup_nis" "./functions/setup_nis.sh"
run_step "setup_nfs" "./functions/setup_nfs.sh"
run_step "setup_clustershell" "./functions/setup_clustershell.sh"
run_step "setup_devtools" "./functions/setup_devtools.sh"
run_step "user_define" "./functions/user_define.sh"

log_info "所有步骤执行完成"
EOF

    chmod +x "$INSTALL_SCRIPT"
    log_info "Install.sh 脚本生成完成"
}

# 主函数
main() {
    check_date
    check_function_files
    check_package_files
    generate_env_file
    generate_install_script

    echo "接下来请执行 Install.sh 脚本"
}

# 执行主函数
main