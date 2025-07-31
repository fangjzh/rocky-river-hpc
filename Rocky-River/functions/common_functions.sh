#!/bin/bash

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

log_warn() {
    echo "[WARN] $1" >&2
}

# 检查并加载环境变量
load_env() {
    if [ -f "./env.text" ]; then
        source ./env.text
    else
        log_error "环境变量文件 env.text 不存在"
    fi
}


# 依据ip和掩码计算网络地址
get_net_addr() {
    local ip="$1"
    local mask="$2"

    # 验证输入格式
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ "$mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "错误：IP地址和子网掩码必须是IPv4格式（如 192.168.1.1 255.255.255.0）"
        return 1
    fi

    # IP转整数函数
    ip_to_int() {
        local ip=(${1//./ })
        echo $(( (${ip[0]}<<24) + (${ip[1]}<<16) + (${ip[2]}<<8) + ${ip[3]} ))
    }

    # 整数转IP函数
    int_to_ip() {
        local int=$1
        echo "$(( (int >> 24) & 0xFF )).$(( (int >> 16) & 0xFF )).$(( (int >> 8) & 0xFF )).$(( int & 0xFF ))"
    }

    local ip_int=$(ip_to_int "$ip")
    local mask_int=$(ip_to_int "$mask")

    # 计算网络地址和广播地址
    local network_int=$((ip_int & mask_int))
    local broadcast_int=$((network_int | ~mask_int & 0xFFFFFFFF))

    # 计算可用IP范围
    local first_usable_int=$((network_int + 1))
    local last_usable_int=$((broadcast_int - 1))

    # 输出基本信息
    # echo "网络地址:    $(int_to_ip $network_int)"
    echo "$(int_to_ip $network_int)"
    # echo "广播地址:    $(int_to_ip $broadcast_int)"
    # echo "可用IP范围:  $(int_to_ip $first_usable_int) - $(int_to_ip $last_usable_int)"
    # echo "可用IP数量:  $((last_usable_int - first_usable_int + 1))"

}