#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi


# 添加用户自定义设置到 .bashrc
add_user_customizations() {
    local bashrc_file="/root/.bashrc"
    
    log_info "添加用户自定义设置到 $bashrc_file"
    
    # 备份原始 .bashrc 文件
    if [ ! -f "${bashrc_file}.bak" ]; then
        cp "$bashrc_file" "${bashrc_file}.bak" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_warn "备份 $bashrc_file 失败"
        fi
    fi
    
    # 检查是否已添加用户自定义标记
    if ! grep -q "## user define" "$bashrc_file"; then
        echo "" >> "$bashrc_file"
        echo "## user define" >> "$bashrc_file"
        if [ $? -ne 0 ]; then
            log_error "写入用户自定义标记到 $bashrc_file 失败"
        fi
    else
        log_info "用户自定义标记已存在"
    fi
    
    # 检查是否已添加 unset command_not_found_handle
    if ! grep -q "unset command_not_found_handle" "$bashrc_file"; then
        echo "unset command_not_found_handle" >> "$bashrc_file"
        if [ $? -ne 0 ]; then
            log_error "写入 unset command_not_found_handle 到 $bashrc_file 失败"
        fi
    else
        log_info "unset command_not_found_handle 已存在"
    fi
}

# 重新加载 .bashrc
reload_bashrc() {
    log_info "重新加载 /root/.bashrc"
    
    # 检查文件是否存在
    if [ -f "/root/.bashrc" ]; then
        source /root/.bashrc >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_warn "重新加载 /root/.bashrc 失败"
        fi
    else
        log_error "/root/.bashrc 文件不存在"
    fi
}

# 主函数
user_define() {
    log_info "执行: 用户自定义设置"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    add_user_customizations
    reload_bashrc
    
    #log_info "执行 $0 : 用户自定义设置完成"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
user_define