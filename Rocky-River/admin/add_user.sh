#!/bin/bash

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 ./functions/common_functions.sh" >&2
    exit 1
fi

# 检查参数
check_arguments() {
    log_info "检查参数"
    
    if [ -z "$1" ]; then
        log_error "未输入用户名，请提供用户名作为参数"
    fi
    
    if [ "$#" -gt 1 ]; then
        log_error "只能一次添加一个用户，请提供单个用户名"
    fi
    
    username="$1"
}

# 检查用户是否已存在
check_user_exists() {
    log_info "检查用户 $username 是否已存在"
    
    if id "$username" >/dev/null 2>&1; then
        log_error "用户 $username 已存在，请选择其他用户名"
    fi
}

# 添加用户
add_user() {
    log_info "添加用户 $username"
    
    # 使用环境变量指定家目录
    if [ -n "${sms_name}" ]; then
        adduser -m -d "/home/${username}" -s "/bin/bash" "$username"
    else
        ## 这里需要改动，如果环境变量里边指定了集群默认数据目录，这里应该从环境中获取这个目录，并使用相应的命令添加用户
        adduser -m -d "/home/${username}" -s "/bin/bash" "$username"
    fi
    
    if [ $? -ne 0 ]; then
        log_error "添加用户 $username 失败"
    fi
    
    log_info "用户 $username 已添加"
}

# 生成随机密码
generate_random_password() {
    password=$(openssl rand -base64 14 | tr -dc 'A-Za-z0-9')
    echo "$password"
}

# 设置用户密码
set_user_password() {
    log_info "设置用户密码"
    
    echo "$username:$password" | chpasswd
    if [ $? -ne 0 ]; then
        log_warn "设置用户密码失败"
    fi
    
    # 将密码写入环境变量文件
    echo "## 用户 $username 的密码：" >>env.user
    echo "export user_${username}_pw=${password}" >>env.user
}

# 设置首次登录修改密码
force_change_password_on_first_login() {
    log_info "设置首次登录修改密码"
    
    if [ -x "/usr/bin/chage" ]; then
        chage -d 0 "$username"
        if [ $? -ne 0 ]; then
            log_warn "设置首次登录修改密码失败"
        else
            log_info "已设置用户 $username 首次登录时必须修改密码"
        fi
    else
        log_warn "/usr/bin/chage 不存在，无法设置首次登录修改密码"
    fi
}

# 更新 NIS 数据库
update_nis_database() {
    log_info "更新 NIS 数据库"
    
    if [ -d "/var/yp" ] && [ -x "/usr/bin/make" ]; then
        make -C /var/yp >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_warn "更新 NIS 数据库失败"
        fi
    else
        log_warn "/var/yp 目录不存在或 make 未安装"
    fi
}

# 配置 Slurm 用户权限
#configure_slurm_user() {
#    log_info "配置 Slurm 用户权限"
#    
#    if [ -f "/etc/slurm/slurm.conf" ]; then
#        if grep -q "AccountingStorageEnforce=account" "/etc/slurm/slurm.conf"; then
#            sacctmgr -i add account "$username" > /dev/null 2>&1
#            if [ $? -ne 0 ]; then
#                log_warn "添加 Slurm 账户失败"
#            fi
#        fi
#    else
#        log_warn "/etc/slurm/slurm.conf 文件不存在"
#    fi
#}

# 主函数
main() {
    log_info "开始执行 $0 : 添加系统用户"
    echo "$0 执行开始！" >${0##*/}.log
    
    load_env
    check_arguments "$@"
    check_user_exists
    add_user
    password=$(generate_random_password)
    set_user_password
    force_change_password_on_first_login
    update_nis_database
    #configure_slurm_user
    
    log_info "用户 $username 已成功添加"
    echo ""
    echo "用户名: $username"
    echo "密码: $password (已写入 env.user 文件)"
    echo "要求首次登录时修改密码"
    echo ""
    echo "请记得将密码安全地传达给用户"
    echo "$0 执行完成！" >>${0##*/}.log
}

# 执行主函数
main "$@"