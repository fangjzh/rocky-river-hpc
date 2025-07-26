#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi


# 安装 MariaDB
install_mariadb() {
    log_info "安装 MariaDB 数据库"
    
    yum -y -q install mariadb-server mariadb >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 MariaDB 失败"
    fi
}

# 配置 MariaDB
configure_mariadb() {
    log_info "配置 MariaDB"
    
    # 备份原始配置文件
    if [ ! -f /etc/my.cnf.d/server.cnf ]; then
        cp /etc/my.cnf /etc/my.cnf.bak
        if [ $? -ne 0 ]; then
            log_warn "备份 /etc/my.cnf 失败"
        fi
    fi
    
    # 可选：配置数据目录到 SSD 分区
    # 注意：实际使用时应确保/home分区是SSD且空间充足
#    if [ -d "/home/mysql" ]; then
#        log_info "检测到已有 /home/mysql 目录"
#    else
#        mkdir -p /home/mysql
#        chown mysql:mysql /home/mysql
#        if [ $? -ne 0 ]; then
#            log_warn "创建 /home/mysql 目录失败，将使用默认数据目录"
#        fi
#    fi
#    
#    # 如果目录存在且可写，配置数据目录
#    if [ -w "/home/mysql" ]; then
#        sed -i '/^datadir/s/^.*$/datadir=\/home\/mysql/g' /etc/my.cnf
#        if [ $? -ne 0 ]; then
#            log_warn "配置自定义数据目录失败"
#        fi
#    fi
}

# 启动 MariaDB 服务
start_mariadb() {
    log_info "启动 MariaDB 服务"
    
    # 启动服务
    systemctl start mariadb.service >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "启动 MariaDB 服务失败"
    fi
    
    # 设置开机自启动
    systemctl enable mariadb.service >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "设置 MariaDB 开机自启动失败"
    fi
}

# 设置 root 密码
set_root_password() {
    log_info "设置 MariaDB root 用户密码"
    
    # 生成随机密码
    # root_password=$(openssl rand -base64 12)
    # root_password='78g*tw23.ysq'
    
    # 设置 root 密码
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${mysql_root_pw}');" >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "设置 root 密码失败"
    fi
    
    log_info "MariaDB root 密码已设置"
}

# 主函数
setup_sql() {
    log_info "执行: 安装设置数据库软件"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    install_mariadb
    configure_mariadb
    start_mariadb
    set_root_password
    
    #log_info "执行 $0 : 安装设置数据库软件完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_sql