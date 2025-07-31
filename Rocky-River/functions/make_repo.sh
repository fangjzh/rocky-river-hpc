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
    local required_vars=("iso_path" "iso_name" "package_dir" "sms_ip")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 创建目录
create_directories() {
    log_info "创建必要目录"
    mkdir -p /opt/repo/rocky
    mkdir -p /media/Rocky
}

# 禁用默认仓库
disable_default_repos() {
    log_info "禁用默认的 Rocky 仓库"
    #perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo
    perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/rocky*.repo
}

# 挂载 ISO 并复制内容
setup_rocky_repo() {
    local iso_file="${iso_path}/${iso_name}"
    
    if [ ! -e "$iso_file" ]; then
        log_error "$iso_file 不存在!!!"
    fi
    
    log_info "挂载 ISO 并复制内容"
    mount -o loop "$iso_file" /media/Rocky  >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "挂载 ISO 失败"
    fi
    
    cp -r /media/Rocky/* /opt/repo/rocky
    umount /media/Rocky
    
    if [ $? -ne 0 ]; then
        log_error "卸载 ISO 失败"
    fi
}

# 解压依赖包
extract_packages() {
    log_info "解压依赖包"
    
    local packages=(
        "${package_dir}/dep-packages.tar:/opt/repo/rocky"
        "${package_dir}/kickstart-crb.tar:/opt/repo/rocky"
        "${package_dir}/openhpc.tar:/opt/repo"
        "${package_dir}/xcat.tar:/opt/repo"
    )
    
    for pkg in "${packages[@]}"; do
        local tar_file="${pkg%:*}"
        local dest_dir="${pkg#*:}"
        
        if [ ! -f "$tar_file" ]; then
            log_error "包文件 $tar_file 不存在"
        fi
        
        tar --no-same-owner -xf "$tar_file" -C "$dest_dir"
        if [ $? -ne 0 ]; then
            log_error "解压 $tar_file 失败"
        fi
    done
}

# 创建本地仓库配置
create_local_repo_config() {
    log_info "创建本地仓库配置文件"
    
    cat <<EOF >/etc/yum.repos.d/Rocky-local.repo
# Rocky-local.repo
#
# You can use this repo to install items directly off the installation local.
# Verify your mount point matches one of the below file:// paths.

[local-baseos]
name=Rocky Linux \$releasever - local - BaseOS
baseurl=file:///opt/repo/rocky/BaseOS
gpgcheck=0
enabled=1

[local-appstream]
name=Rocky Linux \$releasever - local - AppStream
baseurl=file:///opt/repo/rocky/AppStream
gpgcheck=0
enabled=1

[local-crb]
name=Rocky Linux \$releasever - local - PowerTools
baseurl=file:///opt/repo/rocky/kickstart-crb
gpgcheck=0
enabled=1

[local-dep-packages]
name=Rocky Linux \$releasever - local - dep-packages
baseurl=file:///opt/repo/rocky/dep-packages
gpgcheck=0
enabled=1

EOF
}

# 创建 OpenHPC 和 xCAT 仓库
create_additional_repos() {
    log_info "创建 OpenHPC 和 xCAT 仓库"
    
    if [ -x "/opt/repo/openhpc/make_repo.sh" ]; then
        /opt/repo/openhpc/make_repo.sh  >>.install_logs/${0##*/}.log 2>&1
    else
        log_warn "/opt/repo/openhpc/make_repo.sh 不存在或不可执行"
    fi
    
    if [ -x "/opt/repo/xcat/xcat-dep/rh9/x86_64/mklocalrepo.sh" ]; then
        /opt/repo/xcat/xcat-dep/rh9/x86_64/mklocalrepo.sh  >>.install_logs/${0##*/}.log 2>&1
    else
        log_warn "/opt/repo/xcat/xcat-dep/rh9/x86_64/mklocalrepo.sh 不存在或不可执行"
    fi
    
    if [ -x "/opt/repo/xcat/xcat-core/mklocalrepo.sh" ]; then
        /opt/repo/xcat/xcat-core/mklocalrepo.sh   >>.install_logs/${0##*/}.log 2>&1
    else
        log_warn "/opt/repo/xcat/xcat-core/mklocalrepo.sh 不存在或不可执行"
    fi
}

# 更新 yum 缓存
update_yum_cache() {
    log_info "更新 yum 缓存"
    yum clean all >>.install_logs/${0##*/}.log 2>&1
    yum makecache  >>.install_logs/${0##*/}.log 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "更新 yum 缓存失败"
    else
        log_info "更新 yum 缓存成功"
    fi
}

# 配置 HTTP 服务器
setup_http_server() {
    log_info "安装并配置 HTTP 服务器"
    
    yum -y -q install httpd httpd-filesystem httpd-tools dos2unix >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 httpd 失败"
    fi
    
    cat >/etc/httpd/conf.d/repo.conf <<'EOF'
AliasMatch ^/opt/repo/(.*)$ "/opt/repo/$1"
<Directory "/opt/repo">
    Options Indexes FollowSymLinks Includes MultiViews
    AllowOverride None
    Require all granted
</Directory>
EOF
    
    systemctl restart httpd
    if [ $? -ne 0 ]; then
        log_error "重启 httpd 服务失败"
    fi
}

# 为计算节点创建仓库配置
create_compute_node_repo() {
    log_info "为计算节点创建仓库配置"
    
    local repo_file="/opt/repo/compute_node.repo"
    
    # 创建基础仓库配置
    sed 's/file:\//http:\/\/'"${sms_ip}"':80/' /etc/yum.repos.d/Rocky-local.repo > "$repo_file"
    echo "" >> "$repo_file"
    
    # 添加 OpenHPC 仓库配置
    if [ -f /etc/yum.repos.d/OpenHPC.local.repo ]; then
        sed 's/file:\//http:\/\/'"${sms_ip}"':80/' /etc/yum.repos.d/OpenHPC.local.repo >> "$repo_file"
        echo "" >> "$repo_file"
    fi
    
    # 添加 xCAT 仓库配置
    if [ -f /etc/yum.repos.d/xcat-core.repo ]; then
        sed 's/file:\//http:\/\/'"${sms_ip}"':80/' /etc/yum.repos.d/xcat-core.repo >> "$repo_file"
        echo "" >> "$repo_file"
    fi
    
    if [ -f /etc/yum.repos.d/xcat-dep.repo ]; then
        sed 's/file:\//http:\/\/'"${sms_ip}"':80/' /etc/yum.repos.d/xcat-dep.repo >> "$repo_file"
        echo "" >> "$repo_file"
    fi
}

# 主函数
make_repo() {
    log_info "执行: 创建本地软件仓库"
    
    load_env
    check_required_vars
    create_directories
    disable_default_repos
    setup_rocky_repo
    extract_packages
    create_local_repo_config
    create_additional_repos
    update_yum_cache
    setup_http_server
    create_compute_node_repo
    
    #log_info "执行 $0 : 创建本地软件仓库完成"
    echo "$0 执行完成！" >.install_logs/${0##*/}.log
}

# 执行主函数
make_repo