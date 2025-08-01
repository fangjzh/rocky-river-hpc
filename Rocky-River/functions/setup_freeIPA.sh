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
    dnf install ipa-server -y >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 FreeIPA 失败"
    fi
    #ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} -r ${domain_name^^} -p secret12 -n ${domain_name} -U --ds-password 12345678 --admin-password 12345678 >>.install_logs/${0##*/}.log 2>&1
    realm_name=$(echo ${domain_name} | tr 'a-z' 'A-Z')
    ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} --realm=${realm_name} --mkhomedir -r ${domain_name} -p secret12 -n ${domain_name} -U --ds-password ${ipa_ds_password} --admin-password ${ipa_admin_password} >>.install_logs/${0##*/}.log 2>&1
    
    # 添加 SRV 记录
    # 参考 https://docs.redhat.com/zh-cn/documentation/red_hat_enterprise_linux/8/html/installing_identity_management/installing-an-ipa-server-without-integrated-dns_installing-identity-management

    ## 这里xcat 会搞定
#    cat << EOF >> /etc/named.conf
## 添加你自己的主区域
#zone "${domain_name}" IN {
#    type master;               # 这是一个主区域
#    file "${domain_name}.zone"; # 区域文件的名称
#    allow-update { none; };    # 禁止动态更新
#};
#EOF

#    cat << EOF > /var/named/${domain_name}.zone
#\$ORIGIN ${domain_name}.
#\$TTL 86400  ; 默认 TTL，1 天
#
#@ IN SOA ${sms_name}.${domain_name}. root.${domain_name}. (
#                 2025073101 ; Serial (YYYYMMDDNN)
#                 3H         ; Refresh
#                 1H         ; Retry
#                 1W         ; Expire
#                 1D )       ; Minimum TTL
#
#@ IN NS ${sms_name}.${domain_name}. ; 你的主 DNS 服务器 (FreeIPA 服务器)
#${sms_name} IN A ${sms_ip}       ; 为 NS 记录添加对应的 A 记录
#
#EOF

    cat /tmp/ipa.system.records.*.db >> /var/named/db.${domain_name}
    cat /tmp/ipa.system.records.*.db >> db.ipa.backup
    echo "" >> /var/named/db.${domain_name} # 必须有个空行？

    systemctl restart named 

    ##  auto mk home dir
    # authconfig --enablemkhomedir --update

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