#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

# 检查必需的目录是否存在
check_required_directories() {
    log_info "检查必需目录"
    
    local required_dirs=("/opt/ohpc/pub")
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_error "必需目录 $dir 不存在，请先安装 OHPC"
        fi
    done
    
    # 检查 /home 目录
    if [ ! -d "/home" ]; then
        log_warn "/home 目录不存在"
    fi
}

# 配置 exports 文件
configure_exports() {
    log_info "配置 NFS 导出文件"
    
    # 备份原始 exports 文件
    if [ ! -f /etc/exports.bak ]; then
        cp /etc/exports /etc/exports.bak 2>/dev/null
    fi
    
    # 禁用 /tftpboot 和 /install 导出条目
    if [ -f /etc/exports ]; then
        perl -pi -e "s|/tftpboot|#/tftpboot|" /etc/exports
        perl -pi -e "s|/install|#/install|" /etc/exports
    fi
    
    # 添加 NFS 导出条目
    local exports_entries=(
        "/home *(rw,async,no_subtree_check,fsid=10,no_root_squash)"
        "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)"
    )
    
    # 检查条目是否已存在，避免重复添加
    for entry in "${exports_entries[@]}"; do
        local path=$(echo "$entry" | cut -d' ' -f1)
        if ! grep -q "^$path " /etc/exports 2>/dev/null; then
            echo "$entry" >> /etc/exports
            if [ $? -ne 0 ]; then
                log_warn "添加导出条目 $entry 失败"
            fi
        else
            log_info "导出条目 $path 已存在"
        fi
    done
}

# 应用 NFS 配置
apply_nfs_configuration() {
    log_info "应用 NFS 配置"
    sleep 5
    exportfs -a >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "应用 NFS 导出配置失败"
    fi
}

# 启动和启用 NFS 服务
start_nfs_services() {
    log_info "启动和启用 NFS 服务"
    
    systemctl restart nfs-server >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "重启 NFS 服务失败"
    fi
    
    systemctl enable nfs-server >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "启用 NFS 服务开机自启动失败"
    fi
}

# 主函数
setup_nfs() {
    log_info "执行: 安装设置 NFS"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log
    
    load_env
    check_required_directories
    configure_exports
    start_nfs_services
    apply_nfs_configuration
    start_nfs_services
    
    #log_info "执行 $0 : 安装设置 NFS 完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_nfs