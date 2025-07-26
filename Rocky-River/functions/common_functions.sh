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
    if [ -z "${sms_name}" ]; then
        if [ -f "./env.text" ]; then
            source ./env.text
        else
            log_error "环境变量文件 env.text 不存在"
        fi
    fi
}