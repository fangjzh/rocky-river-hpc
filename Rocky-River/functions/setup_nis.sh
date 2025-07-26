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
    local required_vars=("domain_name")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 安装 NIS 包
install_nis_packages() {
    log_info "安装 NIS 相关软件包"
    
    yum install -y -q rpcbind yp-tools ypbind ypserv >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 NIS 软件包失败"
    fi
}

# 配置 NIS 服务
configure_nis_services() {
    log_info "配置 NIS 服务"
    
    # 启用 NIS 服务
    systemctl enable rpcbind ypserv ypxfrd yppasswdd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 NIS 服务失败"
    fi
    
    # 添加 NIS 域名到网络配置
    if ! grep -q "NISDOMAIN=" /etc/sysconfig/network 2>/dev/null; then
        echo "NISDOMAIN=${domain_name}" >> /etc/sysconfig/network
        if [ $? -ne 0 ]; then
            log_warn "写入 NIS 域名到 /etc/sysconfig/network 失败"
        fi
    else
        log_info "NIS 域名已存在于 /etc/sysconfig/network"
    fi
}

# 启动 NIS 服务
start_nis_services() {
    log_info "启动 NIS 服务"
    
    systemctl start rpcbind ypserv ypxfrd yppasswdd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "启动 NIS 服务失败"
    fi
}

# 初始化 NIS 数据库
initialize_nis_database() {
    log_info "初始化 NIS 数据库"
    
    # 等待服务启动
    sleep 6
    
    # 自动初始化 NIS 数据库
    echo "y" | /usr/lib64/yp/ypinit -m >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "初始化 NIS 数据库失败"
    fi
    
    sleep 6
}

# 重启 NIS 服务
restart_nis_services() {
    log_info "重启 NIS 服务"
    
    systemctl restart rpcbind ypserv ypxfrd yppasswdd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "重启 NIS 服务失败"
    fi
}

# 主函数
setup_nis() {
    log_info "执行: 安装设置 NIS"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_nis_packages
    configure_nis_services
    start_nis_services
    initialize_nis_database
    restart_nis_services
    
    #log_info "执行 $0 : 安装设置 NIS 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_nis