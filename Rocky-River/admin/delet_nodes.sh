#!/bin/sh

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 common_functions.sh" >&2
    exit 1
fi

if [ -f "./admin/common_functions.sh" ]; then
    source "./admin/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 ./admin/common_functions.sh" >&2
    exit 1
fi

# 检查必需的环境变量
check_required_vars() {
    local required_vars=("compute_prefix")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_warn "环境变量 $var 未设置"
        fi
    done
}



# 检查参数
check_arguments() {
    log_info "检查参数"
    
    if [ -z "$1" ]; then
        log_warn "未输入节点信息，请提供节点名称作为参数，支持xcat节点写法,例如"
        log_info "cnode001"
        log_info "cnode001,cnode002"
        log_info "cnode[001-100]"
        log_info "cnode001,cnode[006-100]"
        exit 1
    fi
    
    if [ "$#" -gt 1 ]; then
        log_error "只有一个参数，多参数无效"
    fi
    
    node_name="$1"
    echo "将要删除以下节点："
    nodelist $node_name
    if [ $? -ne 0 ]; then
        log_error "节点 $node_name 不存在"
        exit 1
    fi
    nodelist=$(nodelist $node_name)

}

# 删除节点确认
confirm_node_deletion() {
    log_info "删除节点确认"
    
    read -p "是否需要删除节点 $node_name ：(y/n)  " ichoice
    if [[ "$ichoice" != "y" ]]; then
        log_info "取消删除操作"
        exit 0
    fi
}


# 删除节点定义
delete_node_definition() {
    log_info "删除节点定义: $node_name"
    
    #从/etc/hosts文件中删除节点定义
    for node in "${to_delete_nodes[@]}"; do
        # 使用 sed 删除包含节点名称的行（原地修改文件）
        sed -i "/$node\ /d" /etc/hosts
    done

    systemctl restart named

    # 从 confluent 中删除节点定义
    noderemove "$node_name" >>${0##*/}.log 2>&1
    if [ $? -ne 0 ]; then
        log_warn "删除节点定义失败"
    fi
    
}

# 更新 Slurm 配置，单个节点更新
update_slurm_config() {
    log_info "更新 Slurm 配置"
    
    # 如果没有参数，则返回
    if [ -z "$1" ]; then
        log_error "请提供节点名称作为参数"
        return 1
    fi

    local d_node_name="$1"
    # 删除节点 slurm.conf 配置，我只当每个节点信息各占一行
    perl -ni -e "print unless /^NodeName=$d_node_name\s/" /etc/slurm/slurm.conf
    if [ $? -ne 0 ]; then
        log_error "删除节点配置失败"
    fi

    # 解析slurm配置文件，获取分区信息
    local partition_info=($(parse_slurm_partitions "/etc/slurm/slurm.conf"))
    local partition_name=""
    local partition_nodes=()
    local partition_nodes_left=()
    local ifound=false
    local node_list_collapse=""

    for id in "${!partition_info[@]}"; do
        # 从partition_info中提取分区名称（分号前的部分）
        partition_name=$(echo "${partition_info[$id]}" | cut -d':' -f1)
        partition_nodes=($(echo "${partition_info[$id]}" | cut -d':' -f2 | sed 's/,/\ /g'))
        ifound=false
        partition_nodes_left=()
        for item in "${partition_nodes[@]}"; do
            if [[ "$item" != "$d_node_name" ]]; then
                partition_nodes_left+=("$item")
            else
                ifound=true
                echo "删除节点 $d_node_name"
            fi
        done
        if $ifound; then
           #echo  "${partition_nodes_left[@]}"
            if [ ${#partition_nodes_left[@]} -eq 0 ]; then
                ## 分区没有节点了，删除这个分区
                perl -ni -e "print unless /^PartitionName=$partition_name\s/" /etc/slurm/slurm.conf
            else
                node_list_collapse=$(collapse_slurm_node_list "${partition_nodes_left[@]}")
                # 替换原有的分区定义行，只需替换Nodes字段
                perl -i -pe "s/(Nodes=)\S+/Nodes=$node_list_collapse/ if /PartitionName=$partition_name/" /etc/slurm/slurm.conf
            fi
        fi
        
    done

}

# 更新 ClusterShell 配置
update_clustershell_config() {
    log_info "更新 ClusterShell 配置"
    
    if [ -f "/etc/clustershell/groups.d/local.cfg" ]; then
    local allnode_list=($(nodelist))
    local allnode_list_collapse=$(collapse_slurm_node_list "${allnode_list[@]}")
    perl -ni -e "if(/^compute/){print \"compute: ${allnode_list_collapse}\n\"}else{print}" /etc/clustershell/groups.d/local.cfg
        if [ $? -ne 0 ]; then
            log_warn "更新 ClusterShell 配置失败"
        fi
    else
        log_warn "/etc/clustershell/groups.d/local.cfg 文件不存在"
    fi
}

# 主函数
main() {
    log_info "开始执行 $0 : 删除计算节点"
    echo "$0 执行开始！" >${0##*/}.log
    

    load_env
    check_required_vars
    check_arguments "$@"
    confirm_node_deletion

    to_delete_nodes=($(nodelist $@))

    delete_node_definition


    
    # 循环删除节点的列表，执行 update_slurm_config 函数
    for d_host in ${to_delete_nodes[@]}; do
        update_slurm_config $d_host
    done

    update_clustershell_config
    
    log_info "执行 $0 : 计算节点删除完成"
    echo "$0 执行完成！" >>${0##*/}.log
}

# 执行主函数
main "$@"