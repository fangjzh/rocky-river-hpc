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
    local required_vars=("sms_ip" "internal_netmask_l")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 安装 chrony
install_chrony() {
    log_info "安装 chrony"
    
    yum -y -q install chrony >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 chrony 失败"
    fi
}

# 配置 chrony
configure_chrony() {
    log_info "配置 chrony"
    
    # 启用 chronyd 服务
    systemctl enable chronyd.service >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 chronyd.service 失败"
    fi
    
    # 备份原始配置文件
    if [ ! -f /etc/chrony.conf.bak ]; then
        cp /etc/chrony.conf /etc/chrony.conf.bak
        if [ $? -ne 0 ]; then
            log_warn "备份 /etc/chrony.conf 失败"
        fi
    fi
    
    # 添加 NTP 服务器
    echo "server ntp1.aliyun.com iburst" >> /etc/chrony.conf
    echo "server ntp.ntsc.ac.cn iburst" >> /etc/chrony.conf
    
    # 允许内网访问
    echo "allow ${sms_ip}/${internal_netmask_l}" >> /etc/chrony.conf
    
    # 启用本地时钟作为备用
    perl -pi -e "s/#local\ stratum/local\ stratum/" /etc/chrony.conf
    if [ $? -ne 0 ]; then
        log_warn "启用本地时钟作为备用失败"
    fi
}

# 重启 chrony 服务
restart_chrony() {
    log_info "重启 chronyd 服务"
    
    systemctl restart chronyd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "重启 chronyd 服务失败"
    fi
}

# 主函数
setup_ntp() {
    log_info "执行: 安装设置NTP服务"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_chrony
    configure_chrony
    restart_chrony
    
    #log_info "执行 $0 : 安装设置NTP服务完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_ntp