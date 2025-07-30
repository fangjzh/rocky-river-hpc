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
    local required_vars=("sms_eth_internal" "sms_ip" "internal_netmask_l")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 检查网络接口配置文件
check_interface_config() {
    local interface_config="/etc/NetworkManager/system-connections/${sms_eth_internal}.nmconnection"
    
    log_info "检查网络接口配置文件"
    
    if [ ! -e "$interface_config" ]; then
        log_error "$interface_config 不存在"
    fi
}

# 修复网卡名称配置，rocky 9 已经修改配置文件位置和格式了，这里有待改进
fix_interface_name() {
    local interface_config="/etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal}"
    
    log_info "修复网卡名称配置"
    
    # 备份原始配置文件
    if [ ! -f "${interface_config}.bak" ]; then
        cp "$interface_config" "${interface_config}.bak"
        if [ $? -ne 0 ]; then
            log_warn "备份 $interface_config 失败"
        fi
    fi
    
    # 更新 NAME 和 DEVICE 字段
    perl -pi -e "s/NAME=.+/NAME=\"${sms_eth_internal}\"/" "$interface_config"
    if [ $? -ne 0 ]; then
        log_warn "更新 NAME 字段失败"
    fi
    
    perl -pi -e "s/DEVICE=.+/DEVICE=${sms_eth_internal}/" "$interface_config"
    if [ $? -ne 0 ]; then
        log_warn "更新 DEVICE 字段失败"
    fi
    
    # 重新加载网络配置
    nmcli c reload >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "重新加载网络配置失败"
    fi
}

# 配置网络接口
configure_interface() {
    log_info "配置网络接口 ${sms_eth_internal}"
    
    # 设置 IP 地址
    nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l} >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "设置 IP 地址失败"
    fi
    
    # 设置网关
    nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip} >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "设置网关失败"
    fi
    
    # 设置 DNS
    nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip} >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置 DNS 失败"
    fi
    
    # 设置为手动配置
    nmcli conn mod ${sms_eth_internal} ipv4.method manual >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "设置为手动配置失败"
    fi
    
    # 设置路由优先级
    nmcli connection modify ${sms_eth_internal} ipv4.route-metric 199 >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置路由优先级失败"
    fi
    
    # 设置自动连接
    nmcli conn mod ${sms_eth_internal} autoconnect yes >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置自动连接失败"
    fi
}

# 启动网络接口
activate_interface() {
    log_info "激活网络接口 ${sms_eth_internal}"
    
    nmcli conn up ${sms_eth_internal} >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "激活网络接口失败"
    fi
}

# 主函数
setup_network() {
    log_info "执行: 设置网络"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    check_interface_config
    ## fix_interface_name
    configure_interface
    activate_interface
    
    #log_info "执行 $0 : 设置网络完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_network