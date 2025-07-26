#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi


# 安装 OHPC 开发工具
install_ohpc_devtools() {
    log_info "安装 OHPC 开发工具"
    
    # 安装编译器和基础工具
    yum -y -q install ohpc-autotools EasyBuild-ohpc gnu12-compilers-ohpc mpich-ucx-gnu12-ohpc >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 OHPC 基础开发工具失败"
    fi
    
    # 安装 MPI 库
    yum -y -q install openmpi4-gnu12-ohpc mpich-ofi-gnu12-ohpc >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 MPI 库失败"
    fi
    
    # 安装 Lmod 默认配置
    yum -y -q install lmod-defaults-gnu12-openmpi4-ohpc >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装 Lmod 默认配置失败"
    fi
    
    # 安装静态库
    yum -y -q install glibc-static libstdc++-static >>.install_logs/${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "安装静态库失败"
    fi
}

# 查找 Intel 安装包
find_intel_package() {
    local package_pattern="$1"
    local res_tmp=($(find /root /mnt /media /run/media -name "$package_pattern" 2>/dev/null))
    
    if [ -z "${res_tmp[0]}" ]; then
        echo ""
    else
        echo "${res_tmp[0]}"
    fi
}

# 安装 Intel BaseKit
install_intel_basekit() {
    log_info "安装 Intel BaseKit"
    # 返回原始目录
    cd /root
    
    local basekit_script=$(find_intel_package "intel-oneapi-base-toolkit*.sh")
    
    if [ -z "$basekit_script" ]; then
        log_warn "未找到 Intel BaseKit 安装脚本"
        return 0
    fi
    
    # 提取安装包
    sh "$basekit_script" -x >> ${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "提取 Intel BaseKit 安装包失败"
    fi
    
    # 获取解压目录名
    local tmp_folder_p=${basekit_script%.*}
    local tmp_folder=${tmp_folder_p##*/}
    
    # 进入解压目录并安装
    cd "$tmp_folder"
    if [ $? -ne 0 ]; then
        log_error "进入 Intel BaseKit 解压目录失败"
    fi
    
    ./install.sh --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept >> ${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "安装 Intel BaseKit 失败"
    fi
    
    # 返回原始目录
    cd /root
    sleep 6
}

# 安装 Intel HPCKit
install_intel_hpckit() {
    log_info "安装 Intel HPCKit"
    # 返回原始目录
    cd /root
    local hpckit_script=$(find_intel_package "intel-oneapi-hpc-toolkit*.sh")
    
    if [ -z "$hpckit_script" ]; then
        log_warn "未找到 Intel HPCKit 安装脚本"
        return 0
    fi
    
    # 提取安装包
    sh "$hpckit_script" -x >> ${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "提取 Intel HPCKit 安装包失败"
    fi
    
    # 获取解压目录名
    local tmp_folder_p=${hpckit_script%.*}
    local tmp_folder=${tmp_folder_p##*/}
    
    # 进入解压目录并安装
    cd "$tmp_folder"
    if [ $? -ne 0 ]; then
        log_error "进入 Intel HPCKit 解压目录失败"
    fi
    
    ./install.sh --components intel.oneapi.lin.ifort-compiler:intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mpi.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept >> ${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "安装 Intel HPCKit 失败"
    fi
    
    # 返回原始目录
    cd /root
    sleep 6
}

# 配置 Intel 模块
configure_intel_modules() {
    log_info "配置 Intel 模块"
    cd /root
    # 检查安装目录是否存在
    if [ ! -d "/opt/ohpc/pub/apps/intel" ]; then
        log_warn "Intel 安装目录不存在，跳过模块配置"
        return 0
    fi
    
    # 生成模块文件
    /opt/ohpc/pub/apps/intel/modulefiles-setup.sh --output-dir=/opt/ohpc/pub/apps/intel/modulefiles >> ${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "生成 Intel 模块文件失败"
    fi
    
    # 更新 MODULEPATH
    if ! grep -q "intel/modulefiles" /etc/profile.d/lmod.sh; then
        echo 'export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' >>/etc/profile.d/lmod.sh
        if [ $? -ne 0 ]; then
            log_warn "更新 MODULEPATH 失败"
        fi
    else
        log_info "MODULEPATH 已包含 Intel 模块路径"
    fi
}

# 主函数
setup_devtools() {
    log_info "执行: 安装设置开发环境"
    echo "$0 执行开始！" >.install_logs/${0##*/}.log

    tmp_dir=$(pwd)
    
    load_env
    install_ohpc_devtools
    install_intel_basekit
    install_intel_hpckit
    configure_intel_modules
    
    cd "$tmp_dir"
    #log_info "执行 $0 : 安装设置开发环境完毕"
    echo "$0 执行完成！" >>.install_logs/${0##*/}.log
}

# 执行主函数
setup_devtools