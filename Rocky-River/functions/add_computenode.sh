#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

if [ -e new_install.nodes ]; then
    echo "先前安装节点为完成，请先执行after_add_computenode.sh"
    exit
fi

service_stat=($(systemctl status dhcpd | grep Active | grep running))
if [ -z ${service_stat[0]} ]; then
    echo "service dhcpd 未启动"
    exit
fi

. /etc/profile.d/xcat.sh

function check_mac_address() {
    re="([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"
    if [[ $* =~ ${re} ]]; then
        return 0
    else
        return 1
    fi
}

### 取出已有的mac地址
e_macs=($(lsdef -t node -i mac | grep mac | sed 's/mac=//g' | sed 's/ //g'))

### 检测是否提供节点列表
if [ ! -e node_add.list ]; then
    echo "请在node_add.list里提供节点MAC地址！"
    echo "每行一个MAC,格式如：00:50:56:36:D2:9D "
    exit
else
    c_mac=0
    for line in $(cat node_add.list | awk '{print $1}' | sort -u); do
        mac_i=$(echo $line | tr 'a-z' 'A-Z')
        check_mac_address $mac_i
        [ $? -eq 1 ] && break
        if [[ "${e_macs[@]}" =~ $mac_i ]]; then
            echo "与原有节点MAC相同，丢弃"
        else
            macs[$c_mac]=$mac_i
            ((c_mac++))
        fi
    done
fi

if [ $c_mac -eq 0 ]; then
    echo "node_add.list 无有效MAC地址"
    exit
else
    echo "node_add.list 里有 $c_mac 个有效地址"
fi

echo "当前默认节点名前缀 $compute_prefix "
read -p "是否需要修改：(y/n)  " ichoice
if [[ "$ichoice" == "y" ]]; then
    read -p "输入新的前缀名：" cname
    ## 去除其他字符
    cname=$(echo $cname | sed 's/[^a-zA-Z0-9]//g')

    ## 检查是否字母开头
    if [ $(echo $cname | grep ^[a-zA-Z]) ]; then
        echo ""
    else
        echo "必须以字母开头！"
        exit
    fi

    ## 检查字符串长度
    if [ ${#cname} -lt 3 ]; then
        echo "长度必须大于等于3！"
        exit
    elif [ ${#cname} -gt 10 ]; then
        echo "长度必须小于等于10！"
        exit
    fi
    compute_prefix=${cname}
fi

echo "当前节点名前缀 $compute_prefix "

## 列出所有节点
nodelst=($(nodels))
c_node=0
## 将匹配名字的节点后边的数字拿出来
for inode in ${nodelst[@]}; do
    if [[ $inode =~ $compute_prefix ]]; then
        node_nu[$c_node]=$(echo $inode | sed 's/[^0-9]//g')
        if [ ! -z node_nu[$c_node] ]; then
            ((c_node++))
        fi
    fi
done

## 取得最大的数字
if [ $c_node -eq 0 ]; then
    echo "没有相同节点"
    node_max=0
else
    node_max=${node_nu[0]}
    for I in ${node_nu[@]}; do
        if [[ ${node_max} -lt $I ]]; then
            node_max=${I}
        fi
    done
fi

echo "节点 $compute_prefix 最大值：${node_max}"

e_ips=($(lsdef -t node -i ip | grep ip= | sed 's/ip=//g' | sed 's/ //g'))
if [ -z ${e_ips} ]; then
    echo "目前没有节点IP列表"
    max_ip=${c_ip_pre%.*}.100
else
    e_ips=$(echo ${e_ips[@]} | sort -t "." -k1n,1 -k2n,2 -k3n,3 -k4n,4)
    max_ip=${e_ips[-1]}
fi

function nextip() {
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' $(echo $IP | sed -e 's/\./ /g'))
    NEXT_IP_HEX=$(printf %.8X $(echo $((0x$IP_HEX + 1))))
    NEXT_IP=$(printf '%d.%d.%d.%d\n' $(echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'))
    echo "$NEXT_IP"
}

## 循环添加节点
## 这里可以改成一个函数
Sockets=1
CoresPerSocket=1
ThreadsPerCore=1
image_list=($(lsdef -t osimage | grep install | grep compute))
if [ ! -z ${image_list[0]} ]; then
    image_choose=${image_list[0]}
fi

new_node_start=$((${node_max} + 1))
new_node_start=$(printf '%03d\n' ${new_node_start})

for i_mac in ${macs[@]}; do
    max_ip=$(nextip $max_ip)
    ((node_max++))
    node_max=$(printf '%03d\n' ${node_max})
    mkdef -t node ${compute_prefix}${node_max} groups=compute,all ip=${max_ip} mac=${i_mac} netboot=xnba arch=x86_64
    #    nodeset ${compute_prefix}${node_max} osimage=${image_choose}
    chdef ${compute_prefix}${node_max} -p postbootscripts=mypostboot
    echo "NodeName=${compute_prefix}${node_max} Sockets=${Sockets} CoresPerSocket=${CoresPerSocket} \
    ThreadsPerCore=${ThreadsPerCore} State=UNKNOWN" >>/etc/slurm/slurm.conf
done

new_node_end=$(printf '%03d\n' ${node_max})

sed -i '/^PartitionName=normal/d' /etc/slurm/slurm.conf
nodes_name=($(nodels | grep ${compute_prefix} | sed 's/'"${compute_prefix}"'//g' | sort -n))
Nodes=${compute_prefix}[${nodes_name[0]}-${nodes_name[-1]}]
echo "PartitionName=normal Nodes=${Nodes} Default=YES MaxTime=168:00:00 State=UP Oversubscribe=YES" >>/etc/slurm/slurm.conf

if [ ${new_node_start} -lt ${new_node_end} ]; then
    new_node_name_xcat=$(echo "${compute_prefix}${new_node_start}-${compute_prefix}${new_node_end}")
    new_node_name_slurm=$(echo "${compute_prefix}[${new_node_start}-${new_node_end}]")
elif [ ${new_node_start} -eq ${new_node_end} ]; then
    new_node_name_xcat=$(echo "${compute_prefix}${new_node_start}")
    new_node_name_slurm=${new_node_name_xcat}
fi

### update clustershell conf
perl -pi -e "s/compute:/compute: ${new_node_name_slurm}/" /etc/clustershell/groups.d/local.cfg

# Complete network service configurations
makehosts
makenetworks
makedhcp -n
makedns -n

## 还需加入 IPMI 的内容，使新添加节点启动

## 产生一个列表，记录新装的节点名

echo "$new_node_name_xcat $new_node_name_slurm" >new_install.nodes

echo "当计算节点安装完成后（首次启动还需运行mypostboot），再执行 after_add_computenode.sh"
