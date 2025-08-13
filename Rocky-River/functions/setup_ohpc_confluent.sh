#!/bin/bash

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

# 安装 OHPC 和 confluent
install_ohpc_confluent() {
    log_info "安装 OHPC 基础包和 confluent"
    
    yum -y -q install ohpc-base lenovo-confluent confluent_osdeploy-x86_64 tftp-server >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 OHPC 和 confluent 失败"
    fi
    
    systemctl enable confluent --now  >>.install_logs/${0##*/}.log 2>&1
    # systemctl enable httpd --now # if wanting to deploy operating systems and/or the web gui
    systemctl enable tftp.socket --now  >>.install_logs/${0##*/}.log 2>&1  # If wanting to support PXE install
    #systemctl enable httpd --now

    # 配置节点属性
    if [ ! -e "/etc/profile.d/confluent_env.sh" ]; then
        log_error "/etc/profile.d/confluent_env.sh 不存在"
    else
        source /etc/profile.d/confluent_env.sh
    fi 
    
    nodegroupattrib everything deployment.useinsecureprotocols=firmware dns.servers=${sms_ip} dns.domain=${domain_name} net.ipv4_gateway=${sms_ip}
    #nodegroupattrib everything -p bmcuser bmcpass crypted.rootpassword crypted.grubpassword

    echo "y" | ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519


    cp /var/lib/ipa/private/httpd.key /var/lib/ipa/private/httpd.key.bak
    cp /var/lib/ipa/certs/httpd.crt /var/lib/ipa/certs/httpd.crt.bak
    # 创建密钥，用以给confluent 创建简单证书
    mkdir -p /etc/confluent/tls
    openssl pkcs12 -in /root/cacert.p12 -nodes -nocerts -passin pass:${ipa_ds_password} -out /etc/confluent/tls/cakey.pem
    chown confluent:root /etc/confluent/tls/cakey.pem 
    cp /etc/confluent/tls/cacert.pem{,.bak}
    /bin/cp /etc/ipa/ca.crt /etc/confluent/tls/cacert.pem
    ## 系统分发初始化
    osdeploy initialize -a -p -u -s -t >>.install_logs/${0##*/}.log 2>&1

    #mv /var/lib/ipa/private/httpd.key /var/lib/ipa/private/httpd.key.confluent
    #mv /var/lib/ipa/certs/httpd.crt /var/lib/ipa/certs/httpd.crt.confluent

    #cp /var/lib/ipa/private/httpd.key.bak /var/lib/ipa/private/httpd.key
    #cp /var/lib/ipa/certs/httpd.crt.bak /var/lib/ipa/certs/httpd.crt
    
    log_info "导入安装镜像"
    
    local iso_file="${iso_path}/${iso_name}"
    
    if [ ! -e "$iso_file" ]; then
        log_error "$iso_file 不存在"
    fi

    osdeploy import ${iso_file} >>.install_logs/${0##*/}.log 2>&1

    # 定义节点组
    nodegroupdefine compute  >>.install_logs/${0##*/}.log 2>&1

    #nodeattrib compute deployment.apiarmed=continuous  >>.install_logs/${0##*/}.log 2>&1



}



# 配置 postboot 脚本
configure_postboot() {

    # 自定义系统部署配置以及 postboot 脚本，参考 https://hpc.lenovo.com/users/documentation/confluentosdeploy.html

    log_info "配置 postboot 脚本"

    cd /var/lib/confluent/public/os

    local default_deploy_config=$(osdeploy list| grep default | sed 's/ //g')
    local mydefinition_config=${default_deploy_config/default/mydefinition}

    if [ -d "${default_deploy_config}" ] ; then
        cp -a ${default_deploy_config} ${mydefinition_config}
    else
        log_error "默认系统部署配置不存在"
    fi

    cd ${admin_pwd}
    
    local postboot_src="./sample_files/mypostboot.bash"
    local postboot_dst="/var/lib/confluent/public/os/${mydefinition_config}/scripts/firstboot.d/mypostboot"
    #postboot_dst=${postboot_dst// /}    ## 去除空格
    
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
    chown confluent:confluent "$postboot_dst"

    if [ $? -ne 0 ]; then
        log_warn "设置 postboot 脚本可执行权限失败"
    fi
}

# 主函数
setup_ohpc_confluent() {
    log_info "执行: 安装设置 OHPC Base 和 xCAT"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_ohpc_confluent

    configure_postboot
    
    #log_info "执行 $0 : 安装设置 OHPC Base 和 xCAT 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_ohpc_confluent