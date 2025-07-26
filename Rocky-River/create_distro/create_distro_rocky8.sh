#!/bin/bash

# 全局变量
rocky_re="8.10"
openhpc_re="2.8"
openhpc_update_re="2.9.1"  ## 有待完善 @ 2025年7月25日
xcat_re="2.17.0"

## 使用代理下载(OHPC和xCAT)
PROXY_ENABLED="off"  ## on or off 
PROXY_URL="http://192.168.2.89:12306"

# 派生变量
iso_name="Rocky-${rocky_re}-x86_64-dvd1.iso"
xcatc_pkg_name="xcat-core-${xcat_re}-linux.tar.bz2"
xcatd_pkg_name="xcat-dep-${xcat_re}-linux.tar.bz2"
openhpc_pkg_name="OpenHPC-${openhpc_re}.EL_8.x86_64.tar"

# 状态和日志文件
STATE_FILE="/tmp/create_distro_state.txt"
LOG_FILE="/tmp/create_distro.log"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 错误处理
error_exit() {
    log "ERROR: $1"
    exit 1
}

# 安全下载函数，强制使用 IPv4
safe_wget() {
    log "Downloading (IPv4 only): $2"
    wget --inet4-only "$2" -O "$1" || error_exit "Failed to download $2"
}

# 安全下载函数，强制使用 IPv4，可选代理
safe_wget_proxy() {
    local output_file="$1"
    local url="$2"
    local proxy_flag=""

    if [ "$PROXY_ENABLED" = "true" ]; then
        proxy_flag="--proxy=$PROXY_URL"
        log "Downloading via proxy $PROXY_URL: $url"
    else
        log "Downloading (IPv4 only): $url"
    fi

    wget --inet4-only $proxy_flag "$url" -O "$output_file" || error_exit "Failed to download $url"
}

# 检查命令是否成功
check_success() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# 检查步骤是否已完成
step_done() {
    grep -q "$1" "$STATE_FILE" 2>/dev/null
}

# 标记步骤已完成
mark_done() {
    echo "$1" >> "$STATE_FILE"
    log "Step marked as done: $1"
}

# 清理状态文件（可选）
clean_state() {
    > "$STATE_FILE"
    log "State file cleaned."
}

# 下载 ISO 文件
download_iso() {
    local step="download_iso"
    if step_done "$step"; then
        log "ISO already downloaded. Skipping."
        return 0
    fi

    log "Checking for ISO file: $iso_name"
    iso_path=$(find /root /mnt /media /run/media -name "$iso_name" 2>/dev/null | head -n 1)
    if [ -z "$iso_path" ]; then
        log "Downloading ISO file..."
        safe_wget "$iso_name" "https://mirrors.sjtug.sjtu.edu.cn/rocky/${rocky_re}/isos/x86_64/$iso_name"
        iso_path=$(find /root /mnt /media /run/media -name "$iso_name" 2>/dev/null | head -n 1)
    fi
    log "ISO found at: $iso_name"
    mark_done "$step"
}

# 配置 YUM 源
configure_yum_repos() {
    local step="configure_yum_repos"
    if step_done "$step"; then
        log "YUM repositories already configured. Skipping."
        return 0
    fi

    log "Configuring YUM repositories..."
    cat <<EOF > /etc/yum.repos.d/Rocky-kickstart.repo
[kickstart-baseos]
name=Rocky Linux \$releasever - kickstart - BaseOS
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/BaseOS/\$basearch/kickstart/
gpgcheck=0
enabled=1

[kickstart-appstream]
name=Rocky Linux \$releasever - kickstart - AppStream
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/AppStream/\$basearch/kickstart/
gpgcheck=0
enabled=1

[kickstart-powertools]
name=Rocky Linux \$releasever - kickstart - PowerTools
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/PowerTools/\$basearch/kickstart/
gpgcheck=0
enabled=1
EOF

    yum makecache || error_exit "Failed to make YUM cache"
    yum -y install yum-utils createrepo || error_exit "Failed to install required packages"
    mark_done "$step"
}

# 同步 PowerTools 仓库
sync_powertools_repo() {
    local step="sync_powertools_repo"
    if step_done "$step"; then
        log "PowerTools repo already synced. Skipping."
        return 0
    fi

    log "Syncing PowerTools repository..."
    mkdir -p /opt/repo/rocky
    reposync --repoid=kickstart-powertools --exclude 'java-*debug*' --exclude 'dotnet*' -p /opt/repo/rocky/
    check_success "Failed to sync PowerTools repo"
    createrepo /opt/repo/rocky/kickstart-powertools
    cd /opt/repo/rocky && tar -cf /root/kickstart-powertools.tar kickstart-powertools
    mark_done "$step"
}

# 配置 EPEL 和 Fish 源
configure_extra_repos() {
    local step="configure_extra_repos"
    if step_done "$step"; then
        log "EPEL and Fish repositories already configured. Skipping."
        return 0
    fi

    log "Configuring EPEL and Fish repositories..."
    safe_wget "/etc/yum.repos.d/epel.repo" "http://mirrors.aliyun.com/repo/epel-archive-8.repo"
    safe_wget "/etc/yum.repos.d/fish.repo" "https://download.opensuse.org/repositories/shells:/fish:/release:/3/CentOS_8/shells:fish:release:3.repo"
    mark_done "$step"
}

# 下载并配置 OpenHPC 源，这个是已经打包的源
download_openhpc() {
    local step="download_openhpc"
    if step_done "$step"; then
        log "OpenHPC package already processed. Skipping."
        return 0
    fi

    local ohpc_url="http://repos.openhpc.community/dist"
    local ohpc_path=$(find /root /mnt /media /run/media -name "$openhpc_pkg_name" 2>/dev/null | head -n 1)

    if [ -z "$ohpc_path" ]; then
        log "Downloading OpenHPC package..."
        safe_wget_proxy "$openhpc_pkg_name" "$ohpc_url/${openhpc_re}/${openhpc_pkg_name}"
        ohpc_path=$(find /root /mnt /media /run/media -name "$openhpc_pkg_name" 2>/dev/null | head -n 1)
    fi

    mkdir -p /opt/repo/openhpc
    tar -xf "$ohpc_path" -C /opt/repo/openhpc
    rm -f /opt/repo/openhpc/EL_8/x86_64/trilinos-*
    rm -f /opt/repo/openhpc/EL_8/updates/x86_64/trilinos-*
    createrepo /opt/repo/openhpc/EL_8/updates/
    createrepo /opt/repo/openhpc/EL_8/
    /opt/repo/openhpc/make_repo.sh
    cd /opt/repo && tar -cf /root/openhpc.tar openhpc
    log "OpenHPC package processed and archived."
    mark_done "$step"
}

# 下载更新的OpenHPC，这个是散装的
download_openhpc_update() { 
    local ohpc_url="https://repos.openhpc.community/OpenHPC/2/"
    # @ 2025年7月25日
    # 这个还有待完善，思路就是先下载老的完整版本，然后把新的包加进来，或者整个替换update的文件夹
    # 有个问题是如此之后安装软件是否会有多版本之分（整个替换update应该没关系）
}

# 下载并配置 xCAT 源
download_xcat() {
    local step="download_xcat"
    if step_done "$step"; then
        log "xCAT packages already processed. Skipping."
        return 0
    fi

    local xcat_re_p="${xcat_re%.*}"       # 去掉最后一个 .0，得到 2.17
    local xcat_re_pp="${xcat_re_p%.*}"    # 得到 2

    local xcat_url="https://xcat.org/files/xcat"

    local xcatc_pkg_name="xcat-core-${xcat_re}-linux.tar.bz2"
    local xcatd_pkg_name="xcat-dep-${xcat_re}-linux.tar.bz2"

    local xcat_pathc=$(find /root /mnt /media /run/media -name "$xcatc_pkg_name" 2>/dev/null | head -n 1)
    if [ -z "$xcat_pathc" ]; then
        log "Downloading xCAT core package..."
        safe_wget_proxy "$xcatc_pkg_name" "${xcat_url}/xcat-core/${xcat_re_p}.x_Linux/xcat-core/${xcatc_pkg_name}"
        xcat_pathc=$(find /root /mnt /media /run/media -name "$xcatc_pkg_name" 2>/dev/null | head -n 1)
    fi

    local xcat_pathd=$(find /root /mnt /media /run/media -name "$xcatd_pkg_name" 2>/dev/null | head -n 1)
    if [ -z "$xcat_pathd" ]; then
        log "Downloading xCAT dep package..."
        safe_wget_proxy "$xcatd_pkg_name" "${xcat_url}/xcat-dep/${xcat_re_pp}.x_Linux/${xcatd_pkg_name}"
        xcat_pathd=$(find /root /mnt /media /run/media -name "$xcatd_pkg_name" 2>/dev/null | head -n 1)
    fi

    mkdir -p /opt/repo/xcat
    tar -xjf "$xcat_pathc" -C /opt/repo/xcat
    tar -xjf "$xcat_pathd" -C /opt/repo/xcat
    cd /opt/repo/xcat/xcat-dep && rm -rf rh7 rh8/ppc64le/ sles12/ sles15/
    /opt/repo/xcat/xcat-dep/rh8/x86_64/mklocalrepo.sh
    /opt/repo/xcat/xcat-core/mklocalrepo.sh
    cd /opt/repo && tar -cf /root/xcat.tar xcat
    log "xCAT packages processed and archived."
    mark_done "$step"
}

# 下载依赖包并打包
download_dependencies() {
    local step="download_dependencies"
    if step_done "$step"; then
        log "Dependencies already downloaded. Skipping."
        return 0
    fi

    log "Downloading dependencies..."
    yum -y install --downloadonly fish clustershell glibc-static libstdc++-static || error_exit "Failed to download dependencies"

    yum list --repo xcat-dep | grep xcat-dep | awk '{printf "%s ",$1}' >xcat-dep.list
    yum list --repo xcat-core | grep xcat-core | awk '{printf "%s ",$1}' >xcat-core.list
    yum list --repo OpenHPC-local | grep OpenHPC-local | grep -v aarch64 | grep -v '.src ' | awk '{printf "%s ",$1}' >ohpc.list
    yum list --repo OpenHPC-local-updates | grep OpenHPC-local-updates | grep -v aarch64 | grep -v '.src ' | awk '{printf "%s ",$1}' >ohpc-updates.list

    cat xcat-core.list | xargs yum -y install --downloadonly --skip-broken
    cat xcat-dep.list | xargs yum -y install --downloadonly --skip-broken
    cat ohpc.list | xargs yum -y install --downloadonly --skip-broken
    cat ohpc-updates.list | xargs yum -y install --downloadonly --skip-broken
    
    cd ~  ## 返回主目录/root
    mkdir -p dep-packages
    dir=$(find /var/cache/dnf/ -name 'epel*' -type d 2>/dev/null | head -n 1)
    if [ -d "$dir/packages/" ]; then
        cp -r "${dir}/packages/" dep-packages/
    fi

    dir=$(find /var/cache/dnf/ -name 'kickstart-baseos*' -type d 2>/dev/null | head -n 1)
    if [ -d "$dir/packages/" ]; then
        cp -r "${dir}/packages/" dep-packages/
    fi

    dir=$(find /var/cache/dnf/ -name 'kickstart-powertools*' -type d 2>/dev/null | head -n 1)
    if [ -d "$dir/packages/" ]; then
        cp -r "${dir}/packages/" dep-packages/
    fi

    dir=$(find /var/cache/dnf/ -name 'kickstart-appstream*' -type d 2>/dev/null | head -n 1)
    if [ -d "$dir/packages/" ]; then
        cp -r "${dir}/packages/" dep-packages/
    fi

    dir=$(find /var/cache/dnf/ -name 'shells_fish*' -type d 2>/dev/null | head -n 1)
    if [ -d "$dir/packages/" ]; then
        cp -r "${dir}/packages/" dep-packages/
    fi

    createrepo dep-packages
    tar -cf dep-packages.tar dep-packages/
    log "Dependencies downloaded and archived."
    mark_done "$step"
}

# 恢复原始 YUM 源
restore_yum_repos() {
    local step="restore_yum_repos"
    if step_done "$step"; then
        log "YUM repositories already restored. Skipping."
        return 0
    fi

    log "Restoring original YUM repositories..."
    perl -pi -e "s/enabled=0/enabled=1/" /etc/yum.repos.d/Rocky-{AppStream,PowerTools,BaseOS,Extras}.repo
    perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-kickstart.repo
    mark_done "$step"
}

# 主函数
main() {
    set -e
    trap 'error_exit "Script interrupted."' INT TERM

    log "Starting script..."

    # 如果状态文件存在，说明是继续执行
    if [ -f "$STATE_FILE" ]; then
        log "Resuming from previous run..."
    else
        log "Starting new run..."
        touch "$STATE_FILE"
    fi

    download_iso
    configure_yum_repos
    sync_powertools_repo
    configure_extra_repos
    download_openhpc
    download_xcat
    download_dependencies
    restore_yum_repos

    log "Script completed successfully."
}

main