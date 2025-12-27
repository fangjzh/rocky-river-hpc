#!/bin/bash

# 加载公共函数
if [ -f "./functions/common_functions.sh" ]; then
    source "./functions/common_functions.sh"
else
    echo "[ERROR] 无法找到公共函数文件 ./functions/common_functions.sh" >&2
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
    local required_vars=("sms_name" "compute_prefix" "c_ip_pre")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "环境变量 $var 未设置"
        fi
    done
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件"
    
    # 检查是否有未完成的安装
    if [ -e new_install.nodes ]; then
        log_warn "检测到未完成的安装，请先执行 after_add_nodes.sh"
        log_warn "如需强制添加，请删除 new_install.nodes"
        exit 1
    fi
    
    # 检查 confluent 环境
    if ! command -v nodelist >/dev/null 2>&1; then
        log_error "confluent 命令未找到，请确保已正确安装 confluent "
    fi
}



# 验证 MAC 地址格式
check_mac_address() {
    local mac=$1
    local re="^([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}$"
    
    if [[ $mac =~ $re ]]; then
        return 0
    else
        return 1
    fi
}

# 获取现有节点信息
get_existing_node_info() {
    log_info "获取现有节点信息"
    
    # 获取现有 MAC 地址
    existing_macs=($(nodeattrib  compute net.hwaddr | awk '{print $3}'))
    
    # 获取现有 IP 地址
    existing_ips=($(nodeattrib  compute net.ipv4_address | awk '{print $3}'))
    existing_ips+=(${sms_ip})
    
    # 获取现有节点列表
    existing_nodelist=($(nodelist))
}

# 处理节点列表文件
process_node_list_file() {
    log_info "处理节点列表文件"
    
    if [ ! -e node_add.list ]; then
        log_warn "node_add.list 文件不存在，请提供包含 MAC 地址的文件，每行一个MAC，格式如：00:50:56:36:D2:9D"
        echo "#00:50:56:36:D2:9D" > node_add.list
        log_info "已经为你创建一个示例文件，请自行编辑！"
        exit 1
    fi
    
    valid_macs=()
   
    # 提取 MAC 地址第一列并保存到临时文件
    awk '{print $1}' node_add.list > .mac_list.tmp

    while IFS= read -r line; do
        # 跳过空行
        [ -z "$line" ] && continue

        # 规范化 MAC 地址
        mac=$(echo "$line" | tr 'a-z' 'A-Z')

        # 验证 MAC 地址格式（使用 grep 正则）
        echo "$mac" | grep -E '^([0-9A-F]{1,2}:){5}[0-9A-F]{1,2}$' > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_warn "无效 MAC 地址: $mac"
            continue
        fi

        # 检查 MAC 是否重复（现有 MAC）
        echo "${existing_macs[@]}" | grep -w "$mac" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_warn "MAC 地址 $mac 已存在，跳过"
            continue
        fi

        # 检查 MAC 是否重复（当前有效 MAC 列表）
        echo "${valid_macs[@]}" | grep -w "$mac" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_warn "MAC 地址 $mac 重复，跳过"
            continue
        fi

        # 添加到有效 MAC 列表
        valid_macs[(${#valid_macs[@]})]="$mac"

    done < .mac_list.tmp

    # 删除临时文件
    rm -f .mac_list.tmp
    
    if [ ${#valid_macs[@]} -eq 0 ]; then
        log_error "node_add.list 中未找到有效 MAC 地址"
    else
        log_info "找到 ${#valid_macs[@]} 个有效 MAC 地址"
    fi
}

# 修改节点前缀名
modify_node_prefix() {
    log_info "当前默认节点名前缀: $compute_prefix"
    read -p "是否需要修改：(y/n)  " ichoice
    
    if [[ "$ichoice" == "y" ]]; then
        read -p "输入新的前缀名：" new_prefix
        
        # 去除非字母数字字符
        new_prefix=$(echo "$new_prefix" | sed 's/[^a-zA-Z0-9]//g')
        
        # 检查是否以字母开头
        if ! [[ "$new_prefix" =~ ^[a-zA-Z] ]]; then
            log_error "节点名必须以字母开头"
        fi
        
        # 检查长度
        if [ ${#new_prefix} -lt 3 ] || [ ${#new_prefix} -gt 10 ]; then
            log_error "节点名长度必须在 3-10 个字符之间"
        fi
        
        compute_prefix=$new_prefix
    fi
    
    log_info "使用节点名前缀: $compute_prefix"
}

# 给用户选择节点填充还是追加
choose_node_fill_or_append() { 
    while true; do
        read -p "请选择节点填充还是追加？(f/a): " choice
        case "$choice" in
            f|F ) node_fill_or_append="fill"; break ;;
            a|A ) node_fill_or_append="append"; break ;;
            * ) log_error "无效输入，请重新输入。" ;;
        esac
    done
}


# 获取当前相同前缀节点的最大编号
get_current_node_numbers() {
    local node_numbers=()
    local max_number=0
    
    for node in "${existing_nodelist[@]}"; do
        if [[ "$node" =~ "$compute_prefix" ]]; then
            # 去掉前缀，提取数字部分
            number=$(echo "$node" | sed "s/^$compute_prefix//")
            
            if [ -n "$number" ]; then
                node_numbers+=("$number")
            fi
        fi
    done
    
    if [ ${#node_numbers[@]} -gt 0 ]; then
        # 排序并获取最大值
        IFS=$'\n' node_numbers=($(sort -n <<<"${node_numbers[*]}"))
        unset IFS
        max_number=${node_numbers[-1]}
    else
        max_number=0
    fi
    
    echo "$max_number"
}

# 获取下一个 IP 地址
get_next_ip() {
    local ip=$1
    local ip_hex=$(printf '%.2X%.2X%.2X%.2X\n' $(echo "$ip" | sed -e 's/\./ /g'))
    local next_ip_hex=$(printf %.8X $((0x$ip_hex + 1)))
    local next_ip=$(printf '%d.%d.%d.%d\n' $(echo "$next_ip_hex" | sed -r 's/(..)/0x\1 /g'))
    echo "$next_ip"
}




# 创建新节点定义
create_node_definitions() {
    log_info "创建新节点定义"

    # 关闭 SELinux
    setenforce 0
    
    local nodename_start_number=$(get_current_node_numbers)
    local current_ip
    local num_of_add_nodes=${#valid_macs[@]}
    valid_add_ips=()
    valid_add_nodenames=()

        ###########选择填充还是追加#########
    if [ $node_fill_or_append == "append" ]; then  ## 从当前最高位往后填充节点
        # 排序现有 IP，并得到已有IP最高值
        if [ ${#existing_ips[@]} -gt 0 ]; then
            IFS=$'\n' existing_ips=($(sort -t "." -k1n,1 -k2n,2 -k3n,3 -k4n,4 <<<"${existing_ips[*]}"))
            unset IFS
            current_ip=${existing_ips[-1]}
        else
            log_info "没有现有节点 IP 列表"
            current_ip="$sms_ip"
        fi

        # 产生添加的节点 IP 列表 和 名称 列表
        for ((i = 0; i < $num_of_add_nodes; i++)); do
            current_ip=$(get_next_ip "$current_ip")
            valid_add_ips+=("$current_ip")
            nodename_start_number=$(($nodename_start_number + 1))
            valid_add_nodenames+=("${compute_prefix}"$(printf "%03d" "${nodename_start_number}"))
        done

    else  ## 填充式添加节点，比如cnode3和cnode5之间缺少cnode4，新添加的节点会填充到cnode4位置
        # 根据子网信息产生IP地址池，并排除已经存在的IP地址，然后排序
        echo "$c_ip_pre" "$internal_netmask"
        sub_ip_pool=($(list_all_usable_ips "$c_ip_pre" "$internal_netmask"))

        valid_ips=($(array_diff sub_ip_pool existing_ips ))

        #echo "可用IP地址池："
        #echo ${valid_ips[@]}

        if [ ${#valid_ips[@]} -gt 0 ]; then
            IFS=$'\n' valid_ips=($(sort -t "." -k1n,1 -k2n,2 -k3n,3 -k4n,4 <<<"${valid_ips[*]}"))
            unset IFS
            current_ip=${valid_ips[0]}
        else
            log_info "没有现有节点 IP 列表"
            current_ip="$sms_ip"
        fi

        ## 生成节点名称列表
        sub_nodename_pool=()
        for ((i = 1; i < 999; i++)); do
            formatted_node_name=$(printf "%s%03d" "${compute_prefix}" "$i")
            sub_nodename_pool+=("${formatted_node_name}")
        done

        ## 获取已有节点名称列表
        existing_nodename_pool=($(nodelist | grep -E "${compute_prefix}[0-9]+"))

        # 过滤掉已有节点名称
        valid_nodenames=($(array_diff sub_nodename_pool existing_nodename_pool ))

        # 产生添加的节点 IP 列表 和 名称 列表
        for ((i = 0; i < $num_of_add_nodes; i++)); do
            valid_add_ips+=("${valid_ips[i]}")
            valid_add_nodenames+=("${valid_nodenames[i]}")
        done

    fi

    # 循环添加所有节点
    for ((i = 0; i < $num_of_add_nodes; i++)); do 
        log_info "正在添加节点 ${valid_add_nodenames[i]}..."

        echo "${valid_add_nodenames[i]}" "${valid_add_ips[i]}" "${valid_macs[i]}"

        # mkdef -t node "${valid_add_nodenames[i]}" groups=compute,all ip="${valid_add_ips[i]}" mac="${valid_macs[i]}" netboot=xnba arch=x86_64 >>${0##*/}.log 2>&1

        nodedefine "${valid_add_nodenames[i]}" groups=everything,compute net.hwaddr="${valid_macs[i]}" net.ipv4_address="${valid_add_ips[i]}"

        if [ $? -ne 0 ]; then
            log_error "创建节点 ${valid_add_nodenames[i]} 失败"
        fi
        
        confluent2hosts -a "${valid_add_nodenames[i]}" 

        local default_deploy_config=$(osdeploy list| grep default | sed 's/ //g')
        local mydefinition_config=${default_deploy_config/default/mydefinition}

        # 设置节点系统分发
        nodedeploy -n "${valid_add_nodenames[i]}"  -p  ${mydefinition_config}

        echo "NodeName=${valid_add_nodenames[i]} Sockets=${Sockets} CoresPerSocket=${CoresPerSocket} \
        ThreadsPerCore=${ThreadsPerCore} State=UNKNOWN" >>/etc/slurm/slurm.conf

    done


}



# 完成网络服务配置
complete_network_services() {
    log_info "完成网络服务配置"

    systemctl restart named 

    new_node_name_xcat=$(collapse_slurm_node_list "${valid_add_nodenames[@]}")

    # 记录新安装的节点
    echo "$new_node_name_xcat" >new_install.nodes    
}



# 更新 Slurm 分区配置信息
update_slurm_config() {
    log_info "更新 Slurm 配置"

    # 解析slurm配置文件，获取分区信息
    local partition_info=($(parse_slurm_partitions "/etc/slurm/slurm.conf"))

    # 提示用户设置新节点的分区
    #echo "现有的分区信息："
    #echo ${partition_info[@]}

    echo "0. 创建新分区"
    for id in "${!partition_info[@]}"; do
        # 从partition_info中提取分区名称（分号前的部分）
        partition_name=$(echo "${partition_info[$id]}" | cut -d':' -f1)
        echo "$((id+1)). $partition_name"
    done

    while true; do
        read -p "请选择要将新节点添加到的分区（输入序号）: " partition_choice
        if [[ "$partition_choice" =~ ^[0-9]+$ ]] && [ "$partition_choice" -ge 0 ] && [ "$partition_choice" -le "${#partition_info[@]}" ]; then
            break
        else
            echo "无效选择，请输入有效的序号。"
        fi
    done

    local selected_partition="normal"
    if [ "$partition_choice" -eq 0 ]; then
        while true; do
            read -p "请输入新分区的名称: " new_partition_name
            if [[ -n "$new_partition_name" ]]; then
                selected_partition="$new_partition_name"
                break
            else
                echo "分区名称不能为空，请重新输入。"
            fi
        done
    else
        # 从partition_info中提取选中分区的名称
        selected_partition=$(echo "${partition_info[$((partition_choice-1))]}" | cut -d':' -f1)
    fi

    log_info "将新节点添加到分区: $selected_partition"

    local node_list_collapse=""
    if [ "$partition_choice" -eq 0 ] ; then
        node_list_collapse=$(collapse_slurm_node_list "${valid_add_nodenames[@]}")
        echo "PartitionName=$selected_partition Nodes=$node_list_collapse Default=YES MaxTime=720:00:00 State=UP " >>/etc/slurm/slurm.conf
    else
        local existing_node_list=($(echo "${partition_info[$((partition_choice-1))]}" | cut -d':' -f2 | sed 's/,/\ /g'))
        local all_node_list=("${existing_node_list[@]}" "${valid_add_nodenames[@]}")
        node_list_collapse=$(collapse_slurm_node_list "${all_node_list[@]}")
        # 替换原有的分区定义行，只需替换Nodes字段
        perl -i -pe "s/(Nodes=)\S+/Nodes=$node_list_collapse/ if /PartitionName=$selected_partition/" /etc/slurm/slurm.conf
    fi

}

# 更新 ClusterShell 配置
update_clustershell_config() {
    log_info "更新 ClusterShell 配置"
    local allnode_list=($(nodelist))
    local allnode_list_collapse=$(collapse_slurm_node_list "${allnode_list[@]}")
    perl -ni -e "if(/^compute/){print \"compute: ${allnode_list_collapse}\n\"}else{print}" /etc/clustershell/groups.d/local.cfg
    if [ $? -ne 0 ]; then
        log_warn "更新 ClusterShell 配置失败"
    fi
}

# 主函数
main() {
    log_info "开始执行 $0 : 添加计算节点"
    echo "$0 执行开始！" >${0##*/}.log
    
    load_env
    check_required_vars
 
    check_prerequisites
    
    get_existing_node_info
    process_node_list_file
    modify_node_prefix
    choose_node_fill_or_append
 ###
    Sockets=1
    CoresPerSocket=1
    ThreadsPerCore=1
    create_node_definitions

    complete_network_services

    update_slurm_config
    update_clustershell_config

    log_info "计算节点添加完成"
    echo "当计算节点安装完成后（首次启动还需运行 mypostboot），再执行 after_add_nodes.sh"
    echo "$0 执行完成！" >>${0##*/}.log
}

# 执行主函数
main