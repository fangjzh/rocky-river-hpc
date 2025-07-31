#!/bin/bash

# 设置环境变量（这些变量将在部署时被替换）
export sms_ip=10.0.0.1
export domain_name=local
export sms_name=cjhpc

# 日志函数
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# 禁用默认仓库
disable_default_repos() {
    log_info "禁用默认仓库"
    
    #perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo
    perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/rocky*.repo
    perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/local-*.repo
}

# 配置计算节点仓库
configure_compute_repo() {
    log_info "配置计算节点仓库"
    
    wget -O /etc/yum.repos.d/compute_node.repo http://${sms_ip}:80//opt/repo/compute_node.repo
    if [ $? -ne 0 ]; then
        log_error "下载计算节点仓库配置失败"
    fi
    
    yum clean all
    yum makecache
}

# 禁用防火墙
disable_firewall() {
    log_info "禁用防火墙"
    systemctl disable firewalld >/dev/null 2>&1
}

# 配置DNS
configure_dns() {
    log_info "配置DNS"
    
    # 检查是否已存在相同的nameserver条目
    if ! grep -q "^nameserver ${sms_ip}" /etc/resolv.conf; then
        echo "nameserver ${sms_ip}" >>/etc/resolv.conf
    fi
}

# 安装计算节点软件包
install_compute_packages() {
    log_info "安装计算节点软件包"
    
    yum -y -q install ohpc-base-compute.x86_64 lmod-ohpc munge ohpc-slurm-client
    if [ $? -ne 0 ]; then
        log_error "安装计算节点软件包失败"
    fi
}

# 配置Slurm服务
configure_slurm() {
    log_info "配置Slurm服务"
    
    perl -pi -e "s/remote-fs.target.*/remote-fs.target network-online.target/" /usr/lib/systemd/system/slurmd.service
    perl -pi -e 'print"Wants=network-online.target named.service\n" if $. == 4' /usr/lib/systemd/system/slurmd.service
    systemctl daemon-reload
    
    systemctl enable munge >/dev/null 2>&1
    systemctl enable slurmd >/dev/null 2>&1
    echo "SLURMD_OPTIONS=\"--conf-server ${sms_ip}\"" >/etc/sysconfig/slurmd
}

# 设置时区
set_timezone() {
    log_info "设置时区为 Asia/Shanghai"
    timedatectl set-timezone Asia/Shanghai
}

# 配置Autofs
configure_autofs() {
    log_info "配置Autofs"
    
    yum -y -q install autofs
    if [ $? -ne 0 ]; then
        log_error "安装autofs失败"
    fi
    
    systemctl enable autofs >/dev/null 2>&1
    
    # 配置auto.master
    cat >/etc/auto.master <<'EOF'
/-     /etc/auto.pub  --timeout=1200
/home  /etc/auto.home   --timeout=1200
EOF
    
    # 配置NFS挂载点
    echo "/opt/ohpc/pub        ${sms_ip}:/opt/ohpc/pub" >/etc/auto.pub
    echo "*    ${sms_ip}:/home/&" >/etc/auto.home
    
    systemctl restart autofs >/dev/null 2>&1
}

# 更新内存锁定设置
update_memlock_settings() {
    log_info "更新内存锁定设置"
    
    # 检查是否已经设置了memlock
    if ! grep -q "soft memlock unlimited" /etc/security/limits.conf; then
        perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
    fi
    
    if ! grep -q "hard memlock unlimited" /etc/security/limits.conf; then
        perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
    fi
}

# 配置SSH通过资源管理器控制
configure_ssh_with_slurm() {
    log_info "配置SSH通过资源管理器控制"
    
    # 检查是否已添加pam_slurm条目
    if ! grep -q "pam_slurm_adopt.so" /etc/pam.d/sshd; then
        echo "account required pam_slurm_adopt.so" >>/etc/pam.d/sshd
    fi
    
    systemctl restart sshd >/dev/null 2>&1
}


# 配置freeIPA客户端
configure_freeipa_client() { 
    log_info "配置freeIPA客户端"
    yum -y install ipa-client
    #ream_name=$(echo "${domain_name}" | tr '[:lower:]' '[:upper:]')
    #host_name=$(hostname)
    #ipa-client-install --server=ipa.example.com --domain=example.com --realm=EXAMPLE.COM --principal=admin --password=YourAdminPassword --force-join --mkhomedir --no-ntp --enable-dns-updates --force
    # 这里的密码是用来替换的
    #ipa-client-install --hostname=${host_name}.${domain_name}  --mkhomedir  --server=${sms_name}.${domain_name}  --domain ${domain_name}  --force-join --realm ${ream_name} --principal=admin --password 3Pknj7niorIYupjlq7e0ZtX --enable-dns-updates --force -U
    

}


# 主函数
main() {
    log_info "开始执行计算节点后置引导脚本"
    
    chmod +x /etc/rc.d/rc.local

    disable_default_repos
    configure_compute_repo
    disable_firewall
    configure_dns
    install_compute_packages
    configure_slurm
    set_timezone
    configure_autofs
    update_memlock_settings
    configure_ssh_with_slurm
    
    configure_freeipa_client
    
    log_info "计算节点后置引导脚本执行完成"

    echo "postboot finished" > /root/log.postboot.done
}

# 执行主函数
main