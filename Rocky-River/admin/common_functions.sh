#!/bin/bash
# 函数：将节点列表转换为 Slurm 格式
# 参数：传入一个或多个节点名称，例如 "cnode002 cnode003 cnode004 cnode006 xnode08 xnode09 ynode005"
# 输出：Slurm 格式的节点字符串，例如 "cnode[002-006],xnode[08-09],ynode005"
collapse_slurm_node_list() {
    local -A node_groups   # 关联数组，用于存储不同前缀的节点
    local output_list=()   # 用于存储最终的 Slurm 格式字符串

    # 将所有参数作为节点列表处理
    for node in "$@"; do
        # 提取节点前缀和数字部分
        # 使用正则表达式匹配前缀（字母）和数字部分
        if [[ $node =~ ^([a-zA-Z]+)([0-9]+)$ ]]; then
            local prefix="${BASH_REMATCH[1]}"
            local number="${BASH_REMATCH[2]}"

            # 将数字转换为十进制，避免八进制问题
            # 这里我们只将其作为字符串处理，在后续比较和递增时再转换为十进制
            # 这样可以保留原始的零填充格式
            node_groups["$prefix"]+=" $number"
        else
            # 如果节点格式不符合预期，直接添加（不做范围合并）
            output_list+=("$node")
        fi
    done

    # 遍历每个前缀的节点组
    for prefix in "${!node_groups[@]}"; do
        # 将数字部分按数值大小排序
        local -a numbers=($(echo "${node_groups[$prefix]}" | tr ' ' '\n' | sort -n))

        local current_range_start=""
        local last_number=""
        local -a ranges=()

        if [ ${#numbers[@]} -eq 0 ]; then
            continue
        fi

        current_range_start="${numbers[0]}"
        last_number="${numbers[0]}"

        for ((i = 1; i < ${#numbers[@]}; i++)); do
            local current_number="${numbers[i]}"

            # 将数字转换为十进制进行比较，避免八进制问题
            local last_num_decimal=$((10#$last_number))
            local current_num_decimal=$((10#$current_number))

            if (( current_num_decimal == last_num_decimal + 1 )); then
                # 连续的数字，更新最后一个数字
                last_number="$current_number"
            else
                # 不连续，结束当前范围
                if [[ "$current_range_start" == "$last_number" ]]; then
                    ranges+=("$prefix$current_range_start")
                else
                    ranges+=("$prefix[${current_range_start}-${last_number}]")
                fi
                # 开始新范围
                current_range_start="$current_number"
                last_number="$current_number"
            fi
        done

        # 添加最后一个范围
        if [[ "$current_range_start" == "$last_number" ]]; then
            ranges+=("$prefix$current_range_start")
        else
            ranges+=("$prefix[${current_range_start}-${last_number}]")
        fi

        output_list+=($(IFS=,; echo "${ranges[*]}"))
    done

    # 输出最终的 Slurm 格式字符串
    # 对 output_list 再次排序，确保相同前缀的节点在一起，并按前缀字母顺序排列
    # 然后按数字大小排列 (这里只是初步排序，更复杂的排序需要额外逻辑)
    # 对于像 'cnode[002-006],xnode[08-09],ynode005' 这种，按照前缀字母顺序是正确的
    IFS=, eval 'echo "${output_list[*]}" | tr "," "\n" | sort | paste -sd "," -'

}
# --- 示例用法 ---
#echo "--- 示例 1 ---"
#nodes1="cnode002 cnode003 cnode004 cnode006 cnode008 cnode009"
#echo "原始节点列表: $nodes1"
#echo "Slurm 格式: $(collapse_slurm_node_list $nodes1)"


# 展开 Slurm 节点范围，保留前导零（如 node[001-002] -> node001,node002）
expand_node_range() {
    local input=$1
    local result=""

    # 按逗号分割输入字符串
    IFS=',' read -ra parts <<< "$input"

    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^(.*)\[([0-9]+)-([0-9]+)\]$ ]]; then
            # 处理带有范围的节点表达式 (如 node[001-005])
            local prefix=${BASH_REMATCH[1]}
            local start=${BASH_REMATCH[2]}
            local end=${BASH_REMATCH[3]}

            # 确定数字部分的长度（用于保留前导零）
            local len=${#start}

            # 生成范围内的所有节点
            for ((i=10#$start; i<=10#$end; i++)); do
                printf -v num "%0${len}d" $i
                result+="${prefix}${num},"
            done
        else
            # 处理单个节点
            result+="${part},"
        fi
    done

    # 移除最后一个逗号并输出结果
    echo "${result%,}"
}


# 解析 slurm.conf 并展开节点
parse_slurm_partitions() {
    local slurm_conf="${1:-/etc/slurm/slurm.conf}"
    [[ ! -f "$slurm_conf" ]] && { echo "Error: File not found: $slurm_conf" >&2; return 1; }

    awk '
        /^PartitionName=/ {
            partition = nodes = ""
            for (i=1; i<=NF; i++) {
                if ($i ~ /^PartitionName=/) {
                    split($i, a, "=");
                    partition = a[2];
                }
                if ($i ~ /^Nodes=/) {
                    split($i, a, "=");
                    nodes = a[2];
                }
            }
            if (partition && nodes) {
                printf "Partition: %-15s Nodes: %s\n", partition, nodes;
            }
        }
    ' "$slurm_conf" | while read -r line; do
        local partition=$(echo "$line" | awk '{print $2}')
        local nodes_expr=$(echo "$line" | awk '{print $4}')
        local expanded_nodes=$(expand_node_range "$nodes_expr")  
        echo "${partition}:${expanded_nodes}"
    done
}
# 调用函数
#parse_slurm_partitions /etc/slurm/slurm.conf

# 定义函数，从第一个数组中移除第二个数组中的元素
array_diff() {
    local -n arr1=$1  # 使用nameref来引用第一个数组
    local -n arr2=$2  # 使用nameref来引用第二个数组
    local result=()   # 存储结果的数组

    # 遍历第一个数组
    for item1 in "${arr1[@]}"; do
        found=0
        # 检查当前元素是否存在于第二个数组中
        for item2 in "${arr2[@]}"; do
            if [[ "$item1" == "$item2" ]]; then
                found=1
                break
            fi
        done
        # 如果不存在于第二个数组中，则添加到结果数组
        if [[ $found -eq 0 ]]; then
            result+=("$item1")
        fi
    done

    # 输出结果数组
    echo "${result[@]}"
}

# 依据ip和掩码
# 计算并输出所有可用IP地址的函数
list_all_usable_ips() {
    local ip="$1"
    local mask="$2"

    # 验证输入格式
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ "$mask" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "错误：IP地址和子网掩码必须是IPv4格式（如 192.168.1.1 255.255.255.0）"
        return 1
    fi

    # IP转整数函数
    ip_to_int() {
        local ip=(${1//./ })
        echo $(( (${ip[0]}<<24) + (${ip[1]}<<16) + (${ip[2]}<<8) + ${ip[3]} ))
    }

    # 整数转IP函数
    int_to_ip() {
        local int=$1
        echo "$(( (int >> 24) & 0xFF )).$(( (int >> 16) & 0xFF )).$(( (int >> 8) & 0xFF )).$(( int & 0xFF ))"
    }

    local ip_int=$(ip_to_int "$ip")
    local mask_int=$(ip_to_int "$mask")

    # 计算网络地址和广播地址
    local network_int=$((ip_int & mask_int))
    local broadcast_int=$((network_int | ~mask_int & 0xFFFFFFFF))

    # 计算可用IP范围
    local first_usable_int=$((network_int + 1))
    local last_usable_int=$((broadcast_int - 1))

    # 输出基本信息
    # echo "网络地址:    $(int_to_ip $network_int)"
    # echo "广播地址:    $(int_to_ip $broadcast_int)"
    # echo "可用IP范围:  $(int_to_ip $first_usable_int) - $(int_to_ip $last_usable_int)"
    # echo "可用IP数量:  $((last_usable_int - first_usable_int + 1))"
    # echo ""
    # echo "所有可用IP地址："

    # 逐个输出可用IP
    for (( i=$first_usable_int; i<=$last_usable_int; i++ )); do
        int_to_ip $i
    done
}

