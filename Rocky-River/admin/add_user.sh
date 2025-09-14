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
    
    USERNAME="$1"
}

# 检查root 用户授权是否过期
check_root_authorized() {
    log_info "检查root 用户是否被授权"
    
    # 获取 root 账号信息
    USER_INFO=$(ipa user-show root 2>&1) 
    if [ $? -ne 0 ]; then
        if echo "$USER_INFO" | grep -q "Ticket expired"; then
            log_info "root 用户的授权已过期，重新授权"
            echo "${ipa_admin_password}" | kinit admin
        else
            echo "错误: $USER_INFO"
            exit 3
        fi
    fi
    

}

# 检查用户是否已存在
check_user_exists() {
    log_info "检查用户 $USERNAME 是否已存在"
    
    if id "$USERNAME" >/dev/null 2>&1; then
        log_error "用户 $USERNAME 已存在，请选择其他用户名"
    fi

    if ipa user-find "$USERNAME" &>/dev/null; then
        log_error "用户 $USERNAME 已存在于FreeIPA中"
    fi
}

# 添加用户
add_user() {
    log_info "添加用户 $USERNAME"
    
    
    # 生成随机初始密码 (12个字符，包含大小写字母和数字)
    INITIAL_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)

    # 添加FreeIPA用户
    ipa user-add --shell=/bin/bash "$USERNAME" --first="$USERNAME" --last="User" --password <<EOF
$INITIAL_PASSWORD
$INITIAL_PASSWORD
EOF

    if [ $? -ne 0 ]; then
        echo "错误: 创建FreeIPA用户 $USERNAME 失败"
        exit 1
    fi
      
    # 更新一下缓存
    realm_name=$(echo "${domain_name}" | tr 'a-z' 'A-Z')
    id $USERNAME@${realm_name}

    # 将密码写入环境变量文件
    echo "## 用户 $USERNAME 的密码：" >>env.user
    echo "export user_${USERNAME}_pw=${INITIAL_PASSWORD}" >>env.user

    log_info "用户 $USERNAME 已添加"
}


# 创建家目录
create_home_dir() {
    # 创建家目录
    HOME_DIR="/home/$USERNAME"

    if [ ! -d "$HOME_DIR" ]; then
        mkdir -p "$HOME_DIR"
    fi

    USER_INFO=$(ipa user-show "$USERNAME" | grep -E 'UID|GID')
    xUID=$(echo "$USER_INFO" | grep 'UID' | awk '{print $2}')
    xGID=$(echo "$USER_INFO" | grep 'GID' | awk '{print $2}')
    chown -R "$xUID":"$xGID" "$HOME_DIR"
    if [ $? -eq 0 ]; then
        log_info "用户已经生效，已经修改家目录权限"
    else
        log_error "用户暂且未生效，请手动修改家目录权限"
        exit 1
    fi
}

# 主函数
main() {
    log_info "开始执行 $0 : 添加系统用户"
    echo "$0 执行开始！" >${0##*/}.log
    
    load_env
    check_arguments "$@"
    
    check_root_authorized

    check_user_exists
    add_user

    create_home_dir

    log_info "用户 $USERNAME 已成功添加"
    echo ""
    echo "用户名: $USERNAME"
    echo "密码: $INITIAL_PASSWORD (已写入 env.user 文件)"
    echo "要求首次登录时修改密码"
    echo ""
    echo "请记得将密码安全地传达给用户"
    echo "$0 执行完成！" >>${0##*/}.log
}

# 执行主函数
main "$@"