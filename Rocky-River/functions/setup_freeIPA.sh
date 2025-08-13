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



# 安装 FreeIPA
install_freeipa() { 
    # dnf module enable idm:DL1  -y >>.install_logs/${0##*/}.log 2>&1  # Rock Linux 9 没有这个idm了
    # dnf install ipa-server ipa-server-dns -y  # 目前DNS由xcat管理
    dnf install ipa-server ipa-server-dns bind-dyndb-ldap  -y >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 FreeIPA 失败"
    fi
    #ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} -r ${domain_name^^} -p secret12 -n ${domain_name} -U --ds-password 12345678 --admin-password 12345678 >>.install_logs/${0##*/}.log 2>&1
    realm_name=$(echo ${domain_name} | tr 'a-z' 'A-Z')
    ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} --realm=${realm_name} --mkhomedir -r ${domain_name} -p secret12 -n ${domain_name} -U --ds-password ${ipa_ds_password} --admin-password ${ipa_admin_password} --setup-dns --no-ntp --no-forwarders >>.install_logs/${0##*/}.log 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "安装 FreeIPA 失败"
    fi
    
    # 将root用户加入ipa管理员
    echo "${ipa_admin_password}" | kinit admin  >>.install_logs/${0##*/}.log 2>&1
    # 测试
    klist  >>.install_logs/${0##*/}.log 2>&1

}
 



# 主函数
setup_freeIPA() {
    log_info "执行: 安装设置 FreeIPA"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars

    install_freeipa


    
    #log_info "执行 $0 : 安装设置 NIS 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_freeIPA