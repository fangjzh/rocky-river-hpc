#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi


# 检查必需的环境变量
check_required_vars() {
    local required_vars=("sms_name")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 安装 ClusterShell
install_clustershell() {
    log_info "安装 ClusterShell"
    
    yum -y -q install clustershell >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 ClusterShell 失败"
    fi
}

# 配置 ClusterShell 组
configure_clustershell_groups() {
    log_info "配置 ClusterShell 组"
    
    local groups_file="/etc/clustershell/groups.d/local.cfg"
    local backup_file="${groups_file}.orig"
    
    # 备份原始配置文件
    if [ ! -f "$backup_file" ] && [ -f "$groups_file" ]; then
        cp "$groups_file" "$backup_file"
        if [ $? -ne 0 ]; then
            log_warn "备份 $groups_file 失败"
        fi
    fi
    
    # 创建新的配置
    cat > "$groups_file" <<EOF
# ClusterShell default group file
# Syntax: GroupName: host1 host2 host3 ... hostN
# Wildcards ?*[...] are allowed
adm: ${sms_name}
compute: nonode  # 添加节点时需要更改此行
all: @adm,@compute
EOF
    
    if [ $? -ne 0 ]; then
        log_error "写入 ClusterShell 配置文件失败"
    fi
}

# 主函数
setup_clustershell() {
    log_info "执行: 安装设置 ClusterShell"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_clustershell
    configure_clustershell_groups
    
    #log_info "执行 $0 : 安装设置 ClusterShell 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_clustershell