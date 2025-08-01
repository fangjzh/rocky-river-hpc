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
    local required_vars=("sms_name" "sms_eth_internal" "domain_name" "iso_path" "iso_name")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 安装 OHPC 和 xCAT
install_ohpc_xcat() {
    log_info "安装 OHPC 基础包和 xCAT"
    
    yum -y -q install initscripts >>.install_logs/${0##*/}.log 2>&1
        if [ $? -ne 0 ]; then
        log_error "安装 initscripts 失败"
    fi

    yum -y -q install ohpc-base xCAT.x86_64 >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 OHPC 和 xCAT 失败"
    fi
    
    # 修复xCAT 在Rocky Linux 9.6 中的兼容性问题
    # 参考 https://sourceforge.net/p/xcat/mailman/message/59205285/
    sed -i 's/^authorityKeyIdentifier/#authorityKeyIdentifier/g'  /opt/xcat/share/xcat/ca/openssl.cnf.tmpl
    perl -i -pe 's/(-key ca\/dockerhost-key\.pem -out cert\/dockerhost-req\.pem) -extensions server (-subj "\/CN=\$CNA")/$1 $2/' /opt/xcat/share/xcat/scripts/setup-dockerhost-cert.sh

    ## 检查步骤是否已完成
    . /etc/profile.d/xcat.sh
    ## 重新配置xcat
    xcatconfig -i -c -s  >>.install_logs/${0##*/}.log 2>&1
    lsxcatd -a  >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "加载 xCAT 环境变量失败"
    fi
}

# 注册 Rocky Linux 版本信息
register_rocky_version() {
    local discinfo_file="/opt/xcat/lib/perl/xCAT/data/discinfo.pm"
    
    log_info "注册 Rocky Linux 版本信息"
    
    if [ ! -f "$discinfo_file" ]; then
        log_error "$discinfo_file 文件不存在"
    fi
    
    if ! grep -q 'rocky8.10' "$discinfo_file"; then
        perl -pi -e 'print "    \"1716822203.179123\" => \"rocky8.10\",      #x86_64\n" if $. == 17' "$discinfo_file"
        if [ $? -ne 0 ]; then
            log_error "注册 Rocky Linux 8.10 版本信息失败"
        fi
    else
        log_info "Rocky Linux 8.10 版本信息已存在"
    fi

    if ! grep -q 'rocky9.6' "$discinfo_file"; then
        perl -pi -e 'print "    \"1748309243.9338255\" => \"rocky9.6\",      #x86_64\n" if $. == 17' "$discinfo_file"
        if [ $? -ne 0 ]; then
            log_error "注册 Rocky Linux 9.6 版本信息失败"
        fi
    else
        log_info "Rocky Linux 9.6 版本信息已存在"
    fi

}

# 配置 DHCP 接口
configure_dhcp() {
    log_info "配置 DHCP 接口"
    
    #chdef -t site dhcpinterfaces="xcatmn|${sms_eth_internal}"  >>.install_logs/${0##*/}.log 2>&1
    #if [ $? -ne 0 ]; then
    #    log_warn "配置 DHCP 接口失败"
    #fi
    
    chdef -t site domain=${domain_name}  >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置域名失败"
    fi
    
    chdef -t site dhcpinterfaces="${sms_eth_internal}"  >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "重新配置 DHCP 接口失败"
    fi

    #删除初始数据,自动产生的ipv6信息有问题
    tabprune networks -a  >>.install_logs/${0##*/}.log 2>&1 
    # 添加网络配置 
    chtab netname=internal_network networks.net=${c_ip_pre} networks.mask=$internal_netmask networks.gateway=$sms_ip networks.mgtifname=$sms_eth_internal networks.dhcpserver=$sms_ip networks.tftpserver=$sms_ip networks.nameservers=$sms_ip networks.ntpservers=$sms_ip
    makedhcp -n   >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "生成 DHCP 配置失败"
    fi

    makedns -n   >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "生成 DNS 配置失败"
    fi
}

# 配置 NTP 服务器
configure_ntp() {
    log_info "配置 NTP 服务器"
    
    chtab key=ntpservers site.value=${sms_ip}   >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置 NTP 服务器失败"
    fi

   #  makentp >>.install_logs/${0##*/}.log 2>&1

    #makenetworks   >>.install_logs/${0##*/}.log 2>&1
    #if [ $? -ne 0 ]; then
    #    log_warn "生成网络配置失败"
    #fi
}

# 配置 root 密码
configure_root_password() {
    log_info "配置 xCAT 系统 root 密码"
    
    chtab key=system passwd.username=root passwd.password="${xcat_root_pw}"   >>.install_logs/${0##*/}.log 2>&1

    if [ $? -ne 0 ]; then
        log_warn "设置 root 密码失败"
    fi
    
}

# 导入安装镜像
import_install_image() {
    log_info "导入安装镜像"
    
    local iso_file="${iso_path}/${iso_name}"
    
    if [ ! -e "$iso_file" ]; then
        log_error "$iso_file 不存在"
    fi
    
    copycds "$iso_file" >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "导入安装镜像失败"
    fi
}

# 配置 postboot 脚本
configure_postboot() {
    log_info "配置 postboot 脚本"
    
    local postboot_src="./sample_files/mypostboot.bash"
    local postboot_dst="/install/postscripts/mypostboot"
    
    if [ ! -e "$postboot_src" ]; then
        log_error "$postboot_src 不存在"
    fi
    
    /bin/cp "$postboot_src" "$postboot_dst"
    if [ $? -ne 0 ]; then
        log_error "复制 postboot 脚本失败"
    fi
    
    # 替换变量
    sed -i "s/10.0.0.1/${sms_ip}/" "$postboot_dst"
    sed -i "s/sms_name=cjhpc/sms_name=${sms_name}/" "$postboot_dst"
    sed -i "s/domain_name=local/domain_name=${domain_name}/" "$postboot_dst"
    #sed -i "s/3Pknj7niorIYupjlq7e0ZtX/${ipa_admin_password}/" "$postboot_dst"
    
    chmod +x "$postboot_dst"
    if [ $? -ne 0 ]; then
        log_warn "设置 postboot 脚本可执行权限失败"
    fi
}

# 主函数
setup_ohpc_xcat() {
    log_info "执行: 安装设置 OHPC Base 和 xCAT"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_ohpc_xcat
    register_rocky_version
    configure_dhcp
    configure_ntp
    configure_root_password
    import_install_image
    configure_postboot
    
    #log_info "执行 $0 : 安装设置 OHPC Base 和 xCAT 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_ohpc_xcat