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
    local required_vars=("sms_name" "sms_ip" "mysql_root_pw")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 安装 Slurm 组件
install_slurm_packages() {
    log_info "安装 Slurm 及相关组件"
    
    yum -y -q install munge ohpc-slurm-server >>.install_logs/${0##*/}.log 2>&1
    # 以后试试新版，可能有些许区别，比如日志文件配置文件位置等，以后再行测试调整 @ 2025年7月25日
    #yum -y -q install mailx munge slurm-ohpc slurm-slurmctld-ohpc slurm-slurmdbd-ohpc >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 Slurm 包失败"
    fi
    
    systemctl enable munge >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 munge 服务失败"
    fi
}

# 配置 Slurm 数据库
configure_slurm_database() {
    log_info "配置 Slurm 数据库"
    
    # 检查slurmdb用户是否已存在
    user_exists=$(mysql -uroot -p"${mysql_root_pw}" -e "SELECT User FROM mysql.user WHERE User='slurmdb' AND Host='localhost';" 2>/dev/null | grep -c slurmdb)
    
    if [ "$user_exists" -eq 0 ]; then
        # 创建slurmdb用户和数据库
        log_info "创建slurmdb用户和数据库"
        mysql -uroot -p"${mysql_root_pw}" <<EOF
CREATE USER 'slurmdb'@'localhost' IDENTIFIED BY '${slurmdb_pw}';
REVOKE ALL PRIVILEGES ON *.* FROM 'slurmdb'@'localhost';
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'localhost' IDENTIFIED BY '${slurmdb_pw}';
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'${sms_name}' IDENTIFIED BY '${slurmdb_pw}';
FLUSH PRIVILEGES;
EOF
    else
        # 用户已存在，仅更新密码和权限
        log_info "slurmdb用户已存在，更新密码和权限"
        mysql -uroot -p"${mysql_root_pw}" <<EOF
ALTER USER 'slurmdb'@'localhost' IDENTIFIED BY '${slurmdb_pw}';
ALTER USER 'slurmdb'@'${sms_name}' IDENTIFIED BY '${slurmdb_pw}';
REVOKE ALL PRIVILEGES ON *.* FROM 'slurmdb'@'localhost';
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'localhost';
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'${sms_name}';
FLUSH PRIVILEGES;
EOF
    fi
    
    if [ $? -ne 0 ]; then
        log_error "配置 Slurm 数据库失败"
    fi
    
}

# 配置 slurmdbd 服务
configure_slurmdbd() {
    log_info "配置 slurmdbd 服务"
    
    systemctl enable slurmdbd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 slurmdbd 服务失败"
    fi
    
    # 备份原始配置文件
    if [ -f /etc/slurm/slurmdbd.conf ]; then
        mv /etc/slurm/slurmdbd.conf /etc/slurm/slurmdbd.conf.bak
    fi
    
    /bin/cp /etc/slurm/slurmdbd.conf.example /etc/slurm/slurmdbd.conf
    if [ $? -ne 0 ]; then
        log_error "复制 slurmdbd.conf 失败"
    fi
    
    chown slurm.slurm /etc/slurm/slurmdbd.conf
    if [ $? -ne 0 ]; then
        log_warn "设置 slurmdbd.conf 所有者失败"
    fi
    
    # 更新配置
    perl -pi -e "s/StoragePass=\S+/StoragePass=${slurmdb_pw}/" /etc/slurm/slurmdbd.conf
    perl -pi -e "s/StorageUser=\S+/StorageUser=slurmdb/" /etc/slurm/slurmdbd.conf
    perl -pi -e "s/DbdAddr=localhost/DbdAddr=${sms_ip}/" /etc/slurm/slurmdbd.conf
    perl -pi -e "s/DbdHost=localhost/DbdHost=${sms_name}/" /etc/slurm/slurmdbd.conf

    # 添加日志文件
    #mkdir /var/log/slurm/
    touch /var/log/slurm/slurmdbd.log
    chown -R slurm.slurm /var/log/slurm
    #chown slurm.slurm /var/log/slurmctld.log
}

# 配置 slurmctld 服务
configure_slurmctld() {
    log_info "配置 slurmctld 服务"
    
    systemctl enable slurmctld >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 slurmctld 服务失败"
    fi
    
    # 备份原始配置文件
    if [ -f /etc/slurm/slurm.conf ]; then
        mv /etc/slurm/slurm.conf /etc/slurm/slurm.conf.bak
    fi
    
    /bin/cp ./sample_files/slurmconf_ref/slurm.conf /etc/slurm/slurm.conf
    if [ $? -ne 0 ]; then
        log_error "复制 slurm.conf 失败"
    fi
    
    chown slurm.root /etc/slurm/slurm.conf
    if [ $? -ne 0 ]; then
        log_warn "设置 slurm.conf 所有者失败"
    fi
    
    chmod 644 /etc/slurm/slurm.conf
    if [ $? -ne 0 ]; then
        log_warn "设置 slurm.conf 权限失败"
    fi
    
    # 更新配置
    perl -pi -e "s/cjhpc/${sms_name}/" /etc/slurm/slurm.conf
    #perl -pi -e 's|^(\s*StateSaveLocation=)/var/spool/slurmctld|$1/var/spool/slurm/ctld|g' /etc/slurm/slurm.conf

    # 添加日志文件
    touch /var/log/slurm_jobcomp.log
    chown slurm.slurm /var/log/slurm_jobcomp.log
}

# 启动 Slurm 服务
start_slurm_services() {
    log_info "启动 Slurm 服务"
    
    systemctl start munge
    if [ $? -ne 0 ]; then
        log_error "启动 munge 服务失败"
    fi
    
    systemctl start slurmdbd
    if [ $? -ne 0 ]; then
        log_error "启动 slurmdbd 服务失败"
    fi
    
    systemctl start slurmctld
    if [ $? -ne 0 ]; then
        log_error "启动 slurmctld 服务失败"
    fi
}

# 将头节点加入计算节点
add_headnode_as_compute() {
    log_info "将头节点配置为计算节点"
    
    yum -y -q install ohpc-slurm-client >>.install_logs/${0##*/}.log 2>&1
    # 新版以后再尝试
    # yum -y -q install slurm-slurmd-ohpc >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "安装 ohpc-slurm-client 失败"
    fi
    
    echo "SLURMD_OPTIONS=\"--conf-server ${sms_ip}\"" >/etc/sysconfig/slurmd
    if [ $? -ne 0 ]; then
        log_warn "写入 /etc/sysconfig/slurmd 失败"
    fi

    # 执行 lscpu 并提取 Sockets, CoresPerSocket, ThreadsPerCore
    cpu_info=$(lscpu 2>/dev/null)

    if [ $? -ne 0 ]; then
        log_warn "无法获取头节点 CPU 信息"
        return 1
    fi

    # 提取 CPU 架构信息
    Sockets=$(echo "$cpu_info" | grep 'Socket(s)' | awk '{print $2}')
    CoresPerSocket=$(echo "$cpu_info" | grep 'Core(s) per socket' | awk '{print $4}')
    ThreadsPerCore=$(echo "$cpu_info" | grep 'Thread(s) per core' | awk '{print $4}')
    
    echo "NodeName=${sms_name} Sockets=$Sockets CoresPerSocket=$CoresPerSocket ThreadsPerCore=$ThreadsPerCore State=UNKNOWN" >>/etc/slurm/slurm.conf
    echo "PartitionName=head Nodes=${sms_name} Default=YES MaxTime=720:00:00 State=UP Oversubscribe=YES" >>/etc/slurm/slurm.conf
    
    systemctl enable slurmd >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 slurmd 服务失败"
    fi
}

# 配置 systemd 服务
configure_systemd_services() {
    log_info "配置 systemd 服务文件"
    
    mkdir -p ./back_slurm_service
    /bin/cp /usr/lib/systemd/system/slurm*.service ./back_slurm_service
    if [ $? -ne 0 ]; then
        log_warn "备份 systemd 服务文件失败"
    fi
    
    /bin/cp ./sample_files/slurmconf_ref/slurm*.service /usr/lib/systemd/system/
    if [ $? -ne 0 ]; then
        log_error "复制自定义 systemd 服务文件失败"
    fi
    
    chmod 644 /usr/lib/systemd/system/slurm*.service
    if [ $? -ne 0 ]; then
        log_warn "设置 systemd 服务文件权限失败"
    fi
    
    systemctl daemon-reload
    systemctl enable slurmctld >>.install_logs/${0##*/}.log 2>&1
}

# 主函数
setup_slurm() {
    log_info "执行: 安装设置 Slurm"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_vars
    install_slurm_packages
    configure_slurm_database
    configure_slurmdbd
    configure_slurmctld
    start_slurm_services
    add_headnode_as_compute
    configure_systemd_services
    
    #log_info "执行 $0 : 安装设置 Slurm 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_slurm