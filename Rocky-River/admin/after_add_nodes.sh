#!/bin/bash

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件"

    # 如果 $1 不为空，直接传入节点列表，用于重装计算节点后的工作
    if [ -n "$1" ]; then
        renode_name="$1"
    else
        if [ ! -e new_install.nodes ]; then
            log_error "new_install.nodes 文件不存在，请先执行 add_computenode.sh 添加节点"
        fi

        if ! command -v pdsh >/dev/null 2>&1; then
            log_error "pdsh 命令未找到，请确保已安装并配置 xCAT 环境"
        fi
    fi

}

# 加载 xCAT 环境
load_xcat_env() {
    log_info "加载 xCAT 环境"

    if [ -f "/etc/profile.d/xcat.sh" ]; then
        . /etc/profile.d/xcat.sh
    else
        log_error "/etc/profile.d/xcat.sh 文件不存在"
    fi
}

# 获取节点信息
get_node_info() {
    log_info "获取节点信息"

    if [ -n "$renode_name" ]; then
        log_info "正在重建节点 $renode_name"
        nodes_xcat=$renode_name
    else
        # 读取新安装的节点信息
        read -r nodes_xcat <<< "$(cat new_install.nodes)"
    fi

    if [ -z "$nodes_xcat" ] ; then
        log_error "new_install.nodes 文件格式不正确或为空"
    fi

    log_info "新安装的节点: $nodes_xcat"
}


# 检测节点状态
check_node_status() {
    log_info "检测节点状态"

    local nodes_array=($(nodels "$nodes_xcat"))

    # 如果nodes_array为空，则执行nodels命令
    if [ "${#nodes_array[@]}" -eq 0 ]; then
        log_error "未找到节点"
    fi

    # 等待所有节点准备就绪
    local all_ready=false
    local wait_count=0
    local max_wait=6  # 最多等待6次，每次10秒，总共1分钟
    
    while [ "$all_ready" = false ] && [ $wait_count -lt $max_wait ]; do
        all_ready=true
        local unready_nodes=""
        
        # 检查每个节点是否能SSH登录以及是否存在 /root/log.postboot.done 文件
        for node in "${nodes_array[@]}"; do
            # 首先检查SSH连接是否可用
            log_info "Checking SSH connection to $node..."
            if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$node" exit 2>/dev/null; then
                all_ready=false
                unready_nodes="$unready_nodes $node"
                log_info "节点 $node SSH连接失败或未就绪"
                continue
            fi
            
            # SSH连接成功后，检查 /root/log.postboot.done 文件是否存在
            if ! ssh "$node" [ -f /root/log.postboot.done ] >/dev/null 2>&1; then
                all_ready=false
                unready_nodes="$unready_nodes $node"
                log_info "节点 $node SSH连接成功但未就绪"
            else
                log_info "节点 $node 已准备就绪"
            fi
        done
        
        if [ "$all_ready" = false ]; then
            wait_count=$((wait_count + 1))
            log_info "等待节点 $unready_nodes 准备就绪 ($wait_count/$max_wait)..."
            sleep 10
        fi
    done
    
    if [ "$all_ready" = true ]; then
        log_info "所有节点均已准备就绪"
        return 0
    else
        log_warn "部分节点未在规定时间内准备就绪:$unready_nodes"
        log_warn "退出脚本"
        exit 1
    fi
}


# 获取远程节点 CPU 架构信息
get_remote_cpu_info() {
    log_info "获取远程节点 CPU 架构信息"

    local node="$1"

    log_info "从节点 $node 获取 CPU 架构信息"

    # 在远程节点执行 lscpu 并提取 Sockets, CoresPerSocket, ThreadsPerCore
    cpu_info=$(ssh "$node" "lscpu" 2>/dev/null)

    if [ $? -ne 0 ]; then
        log_warn "无法通过 SSH 连接节点 $node 获取 CPU 信息"
        return 1
    fi

    # 提取 CPU 架构信息
    Sockets=$(echo "$cpu_info" | grep 'Socket(s)' | awk '{print $2}')
    CoresPerSocket=$(echo "$cpu_info" | grep 'Core(s) per socket' | awk '{print $4}')
    ThreadsPerCore=$(echo "$cpu_info" | grep 'Thread(s) per core' | awk '{print $4}')

    if [ -z "$Sockets" ] || [ -z "$CoresPerSocket" ] || [ -z "$ThreadsPerCore" ]; then
        log_warn "无法获取完整的 CPU 架构信息"
        return 1
    fi

    log_info "获取到 CPU 架构信息：Sockets=$Sockets, CoresPerSocket=$CoresPerSocket, ThreadsPerCore=$ThreadsPerCore"
    return 0
}

# 更新 slurm.conf 文件中的节点 CPU 架构信息
update_slurm_node_config() {
    log_info "更新 /etc/slurm/slurm.conf 中的节点 CPU 架构信息"

    local node="$1"
    local config_line="NodeName=$node Sockets=$Sockets CoresPerSocket=$CoresPerSocket ThreadsPerCore=$ThreadsPerCore State=UNKNOWN"

    # 检查是否已存在该节点配置
    if grep -q "^NodeName=$node " /etc/slurm/slurm.conf; then
        log_info "更新节点 $node 的配置"
        perl -pi -e "s/^NodeName=$node .*/$config_line/" /etc/slurm/slurm.conf
    else
        log_info "添加新节点 $node 的配置"
        echo "$config_line" >> /etc/slurm/slurm.conf
    fi

    if [ $? -ne 0 ]; then
        log_warn "更新 /etc/slurm/slurm.conf 失败"
        return 1
    fi

    return 0
}

# 同步 munge.key
sync_munge_key() {
    log_info "同步 munge.key 到计算节点"

    if [ ! -f "/etc/munge/munge.key" ]; then
        log_error "/etc/munge/munge.key 文件不存在"
    fi

    # 使用 xCAT 的 xdcp 命令同步
    xdcp "$nodes_xcat" /etc/munge/munge.key /etc/munge/munge.key >>${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_error "使用 xdcp 同步 munge.key 失败!!"
    fi
}

# 配置 Intel 编译器模块
configure_intel_module() {
    log_info "配置 Intel 编译器模块"

    # 检查模块路径是否存在 # 此种检测方式有问题，无论是host找不到，还是执行了返回非零，都会为True
    if pdsh -w "$nodes_xcat" test -f "/opt/ohpc/pub/apps/intel/modulefiles-setup.sh"; then  
        log_info "Intel 模块配置文件存在"
    else
        log_warn "Intel 模块配置文件不存在，可能未安装 Intel 编译器"
        return 0
    fi

    # 添加 MODULEPATH 
    pdsh -w "$nodes_xcat" "echo 'export MODULEPATH=\$MODULEPATH:/opt/ohpc/pub/apps/intel/modulefiles' >> /etc/profile.d/lmod.sh" >>${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then   ### 同样，$?无法表示执行是否成功
        log_warn "配置 Intel 模块路径失败"
    fi
}

# 同步时间
synchronize_time() {
    log_info "同步计算节点时间"

    if [ -x "/usr/bin/chronyc" ]; then
        pdsh -w "$nodes_xcat" "chronyc -a makestep" >>${0##*/}.log 2>&1
        if [ $? -ne 0 ]; then
            log_warn "时间同步失败"
        fi
    else
        log_warn "chronyc 命令不存在，时间同步未执行"
    fi
}

# 计算节点安装freeIPA client
install_freeipa_client() { 
    log_info "安装freeIPA client"
    realm_name=$(echo ${domain_name} | tr 'a-z' 'A-Z')
    pdsh -w "$nodes_xcat" "ipa-client-install --hostname=\`hostname\`.${domain_name}  --mkhomedir  --server=${sms_name}.${domain_name}  --domain=${domain_name} --realm=${realm_name} --force-join --principal=admin --password $ipa_admin_password --enable-dns-updates --force -U" >>${0##*/}.log 2>&1
}

# 重启节点服务
restart_node_services() {
    log_info "重启节点服务"

    # 重启 slurmctld
    systemctl restart slurmctld >>${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "重启 slurmctld 服务失败"
    fi

    # 重启 munge 和 slurmd 服务
    pdsh -w "$nodes_xcat" "systemctl restart munge && systemctl restart slurmd" >>${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "重启 munge 和 slurmd 服务失败"
    fi
}


# 更新节点状态
update_node_status() {
    log_info "更新节点状态"

    if [ -x "/usr/bin/scontrol" ]; then
        scontrol update NodeName="$nodes_xcat" State=RESUME >>${0##*/}.log 2>&1
        if [ $? -ne 0 ]; then
            log_warn "更新节点状态失败"
        fi
    else
        log_warn "scontrol 命令不存在，无法更新节点状态"
    fi
}

# 清理临时文件
cleanup_temp_files() {
    log_info "清理临时文件"

    if [ -f "new_install.nodes" ]; then
        echo "是否清理 new_install.nodes 文件？"
        echo "注意：如果需要重新运行此脚本，请选择 'n' 保留该文件"
        read -p "请输入 (y/n): " choice
        
        case "$choice" in
            y|Y|yes|YES)
                rm new_install.nodes
                if [ $? -ne 0 ]; then
                    log_warn "清理 new_install.nodes 文件失败"
                else
                    log_info "new_install.nodes 文件已清理"
                fi
                ;;
            *)
                log_info "保留 new_install.nodes 文件"
                ;;
        esac
    fi
}

# 主函数
main() {
    log_info "开始执行 $0 : 完成计算节点添加后续工作"
    echo "$0 执行开始！" >${0##*/}.log

    load_env
    load_xcat_env
    check_prerequisites $1
    get_node_info
    check_node_status

    ## 依据计算节点硬件更新头节点的slurm 配置文件
    # 访问特定元素 (例如，第一个元素)
    n_array=($(nodels "$nodes_xcat"))
    if get_remote_cpu_info "${n_array[0]}"; then
        # 逐个更新所有节点的 slurm.conf 配置
        for node in "${n_array[@]}"; do
            update_slurm_node_config "$node"
        done
    else
        log_warn "获取 CPU 架构信息失败，跳过 slurm.conf 更新"
    fi

    sync_munge_key
    configure_intel_module
    synchronize_time
    install_freeipa_client
    restart_node_services
    update_node_status
    cleanup_temp_files

    log_info "执行 $0 : 计算节点添加完成"
    echo "$0 执行完成！" >>${0##*/}.log
}

# 执行主函数
main $1