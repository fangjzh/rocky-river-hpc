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
    local required_vars=("sms_name" "sms_ip" "domain_name")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 设置时区
setup_timezone() {
    log_info "设置时区为 Asia/Shanghai"
    
    timedatectl set-timezone Asia/Shanghai
    if [ $? -ne 0 ]; then
        log_error "设置时区失败"
    fi
}

# 设置主机名
setup_hostname() {
    log_info "设置主机名为 ${sms_name}"
    
    echo "${sms_name}" >/etc/hostname
    if [ $? -ne 0 ]; then
        log_error "写入 /etc/hostname 失败"
    fi
    
    # 添加主机名到 /etc/hosts
    echo "${sms_ip}  ${sms_name}.${domain_name}  ${sms_name}" >>/etc/hosts
    if [ $? -ne 0 ]; then
        log_error "写入 /etc/hosts 失败"
    fi
    
    # 使用 nmcli 设置主机名
    nmcli g hostname ${sms_name}
    if [ $? -ne 0 ]; then
        log_warn "使用 nmcli 设置主机名失败"
    fi
}

# 禁用防火墙
disable_firewall() {
    log_info "禁用防火墙"
    
    systemctl disable firewalld >/dev/null 2>&1
    systemctl stop firewalld >/dev/null 2>&1
    
    if systemctl is-active firewalld >/dev/null 2>&1; then
        log_warn "防火墙可能未完全停止"
    else
        log_info "防火墙已成功禁用"
    fi
}

# 禁用 SELinux
disable_selinux() {
    log_info "禁用 SELinux"
    
    # 临时禁用 SELinux
    setenforce 0
    if [ $? -ne 0 ]; then
        log_warn "临时禁用 SELinux 失败"
    fi
    
    # 永久禁用 SELinux
    if [ -f "/etc/sysconfig/selinux" ]; then
        perl -pi -e "s/SELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
        if [ $? -ne 0 ]; then
            log_warn "永久禁用 SELinux 失败"
        fi
    else
        log_warn "/etc/sysconfig/selinux 文件不存在"
    fi
}

# 禁用 IPv6
disable_ipv6() {
    log_info "禁用 IPv6"
    
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
    if [ $? -ne 0 ]; then
        log_error "写入 /etc/sysctl.conf 失败"
    fi
    
    sysctl -p /etc/sysctl.conf >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_warn "应用 sysctl 配置失败"
    fi
}

# 更新内存锁定设置
update_memlock_settings() {
    log_info "更新内存锁定设置"
    
    # 检查是否已经设置了 memlock
    if ! grep -q "soft memlock unlimited" /etc/security/limits.conf; then
        perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
        if [ $? -ne 0 ]; then
            log_warn "设置 soft memlock 失败"
        fi
    fi
    
    if ! grep -q "hard memlock unlimited" /etc/security/limits.conf; then
        perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
        if [ $? -ne 0 ]; then
            log_warn "设置 hard memlock 失败"
        fi
    fi
}

# 主函数
set_headnode() {
    log_info "执行: 头节点时区、hostname、防火墙设置"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    setup_timezone
    setup_hostname
    disable_firewall
    disable_selinux
    disable_ipv6
    update_memlock_settings
    
    #log_info "执行 $0 : 头节点时区、hostname、防火墙设置完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
set_headnode