#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

# IP检查函数
check_ip() {
    local IP=$1
    VALID_CHECK=$(echo $IP | awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
            return 0
        else
            log_error "IP $IP 不可用！"
            return 1
        fi
    else
        log_error "IP 格式错误！"
        return 1
    fi
}

# 计算子网掩码位数
maskdigits() {
    local mask=$1
    local bits=0
    
    # 将掩码转换为二进制并计算1的个数
    for octet in $(echo $mask | tr '.' ' '); do
        if [ $octet -lt 0 ] || [ $octet -gt 255 ]; then
            log_error "子网掩码无效: $mask"
            return 1
        fi
        
        while [ $octet -ne 0 ]; do
            bits=$((bits + (octet & 1)))
            octet=$((octet >> 1))
        done
    done
    
    echo $bits
}

# 获取可用网卡列表
get_network_interfaces() {
    ls /sys/class/net | grep -E 'ens|eth|eno|enp|ib' 2>/dev/null || echo ""
}

# 选择内网网卡
select_network_interface() {
    echo "请选择内网（负责系统管理和系统分发）网卡，可选的网络端口名："
    local net_name=($(get_network_interfaces))
    
    if [ ${#net_name[@]} -eq 0 ]; then
        log_error "未找到可用的网络接口"
        exit 1
    fi
    
    echo "${net_name[*]}"
    # 显示每个网络接口及其IP地址
    for iface in "${net_name[@]}"; do
        local ip_addr=$(ip addr show "$iface" 2>/dev/null | grep -o 'inet [0-9.]*' | head -1 | cut -d' ' -f2)
        if [ -n "$ip_addr" ]; then
            echo "$iface (IP: $ip_addr)"
        else
            echo "$iface (IP: 无)"
        fi
    done   

    while true; do
        read -p "网卡: " sms_eth_internal
        if [ -z "${sms_eth_internal}" ]; then
            log_error "网卡名不能为空，请重新输入！"
            continue
        elif [ ! -d /sys/class/net/${sms_eth_internal} ]; then
            log_error "网卡 ${sms_eth_internal} 不存在，请重新输入！"
            continue
        else
            break
        fi
    done
    

    echo "## 内网网卡：" >>env.text
    echo "export sms_eth_internal=${sms_eth_internal}" >>env.text
    echo "## OS分发网卡：" >>env.text
    echo "export eth_provision=${sms_eth_internal}" >>env.text
}

# 输入并验证IP地址
input_ip() {
    local prompt="$1"
    local var_name="$2"
    
    while true; do
        read -p "$prompt" ip_value
        if check_ip $ip_value; then
            echo "## $var_name：" >>env.text
            echo "export $var_name=${ip_value}" >>env.text
            echo $ip_value
            break
        fi
    done
}

# 输入并验证子网掩码
input_netmask() {
    while true; do
        read -p "输入子网掩码（eg. 255.255.255.0）: " internal_netmask
        if check_ip $internal_netmask; then
            echo "## 内网子网掩码：" >>env.text
            echo "export internal_netmask=${internal_netmask}" >>env.text
            break
        fi
    done
    
    # 计算子网掩码长度
    internal_netmask_l=$(maskdigits ${internal_netmask})
    if [ $? -ne 0 ]; then
        log_error "无法计算子网掩码长度"
        exit 1
    fi
    
    echo "## 内网子网掩码长度：" >>env.text
    echo "export internal_netmask_l=${internal_netmask_l}" >>env.text
}

# 询问并配置IB网络
configure_ib_network() {
    while true; do
        read -p "是否启用IB网络用于计算负载通信？(y/n): " enable_ib
        case $enable_ib in
            [Yy]* )
                setup_ib_network
                break
                ;;
            [Nn]* )
                # 使用默认值或现有设置
                echo "## IB网络未启用" >>env.text
                echo "export enable_ib=false" >>env.text
                break
                ;;
            * )
                echo "请输入 y 或 n"
                ;;
        esac
    done
}


# 设置IB网络
setup_ib_network() {
    echo "请选择用于计算负载通信的IB网络接口，可选的网络端口名："
    local ib_interfaces=($(get_network_interfaces))
    
    if [ ${#ib_interfaces[@]} -eq 0 ]; then
        log_error "未找到可用的IB网络接口"
        echo "## IB网络未启用" >>env.text
        echo "export enable_ib=false" >>env.text
        return
    fi
    
    # 显示每个IB网络接口及其IP地址
    for iface in "${ib_interfaces[@]}"; do
        local ip_addr=$(ip addr show "$iface" 2>/dev/null | grep -o 'inet [0-9.]*' | head -1 | cut -d' ' -f2)
        if [ -n "$ip_addr" ]; then
            echo "$iface (IP: $ip_addr)"
        else
            echo "$iface (IP: 无)"
        fi
    done
    
    while true; do
        read -p "IB网卡: " ib_interface
        if [ -z "${ib_interface}" ]; then
            log_error "网卡名不能为空，请重新输入！"
            continue
        elif [ ! -d /sys/class/net/${ib_interface} ]; then
            log_error "网卡 ${ib_interface} 不存在，请重新输入！"
            continue
        else
            break
        fi
    done
    
    # 获取IB网络IP地址
    ib_ip=$(input_ip "输入IB网络IP（例如 10.0.1.1）: " "sms_ipoib")
    
    # 获取IB网络子网掩码
    echo "输入IB网络子网掩码："
    input_ib_netmask
    
    # 设置IB网络相关参数
    echo "## 启用IB网络" >>env.text
    echo "export enable_ib=true" >>env.text
    echo "## IB网络接口" >>env.text
    echo "export ib_interface=${ib_interface}" >>env.text
    echo "## IB网络计算节点IP网段" >>env.text
    echo "export c_ipoib_pre=${ib_ip}" >>env.text
}

# 输入并验证IB网络子网掩码
input_ib_netmask() {
    while true; do
        read -p "输入IB网络子网掩码（例如 255.255.255.0）: " ipoib_netmask
        if check_ip $ipoib_netmask; then
            echo "## IB网络子网掩码：" >>env.text
            echo "export ipoib_netmask=${ipoib_netmask}" >>env.text
            break
        fi
    done
    
    # 计算子网掩码长度
    ipoib_netmask_l=$(maskdigits ${ipoib_netmask})
    if [ $? -ne 0 ]; then
        log_error "无法计算子网掩码长度"
        exit 1
    fi
    
    echo "## IB网络子网掩码长度：" >>env.text
    echo "export ipoib_netmask_l=${ipoib_netmask_l}" >>env.text
}


# 主函数
reg_network() {
    # 选择内网网卡
    select_network_interface
    
    # 输入内网IP
    sms_ip=$(input_ip "输入内网 IP（eg. 10.0.0.1）: " "sms_ip")
    
    # 设置NTP服务器IP
    echo "## 计算节点NTP时间服务器IP：" >>env.text
    echo "export ntp_server=${sms_ip}" >>env.text
    
    # 输入子网掩码
    input_netmask
    
    # 设置计算节点相关参数
    echo "## 计算节点名字前缀：" >>env.text
    echo "export compute_prefix=cnode" >>env.text
    echo "## 内网网络地址：" >>env.text
    c_ip_pre=$(get_net_addr ${sms_ip}  ${internal_netmask})
    echo "export c_ip_pre=${c_ip_pre}" >>env.text
    
    # 询问并配置IB网络（只有开头，后续需要对xcat 和 slurm 完成自动配置功能，还有相当多的事情要做）
    # configure_ib_network

    # 设置BMC管理网络（暂未实现）

    
    log_info "网络参数设置完毕！"
}

# 执行主函数
reg_network