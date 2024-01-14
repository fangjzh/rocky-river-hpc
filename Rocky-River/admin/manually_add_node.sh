#!/bin/sh
## 这个脚本还未完成，作为一个参考脚本
. /etc/profile.d/xcat.sh

if [ -z $1 ]; then
    echo "未输入节点信息，退出！"
    exit
fi

## 这里是需要手动修改的部分
i_mac=00:0C:29:D5:BE:17
compute_prefix=cnode
node_max=003
max_ip=10.0.0.103

mkdef -t node ${compute_prefix}${node_max} groups=compute,all ip=${max_ip} mac=${i_mac} netboot=xnba arch=x86_64
chdef ${compute_prefix}${node_max} -p postbootscripts=mypostboot

image_list=($(lsdef -t osimage | grep install | grep compute))
if [ ! -z ${image_list[0]} ]; then
    image_choose=${image_list[0]}
fi

makehosts ${compute_prefix}${node_max}
makedhcp ${compute_prefix}${node_max}
makedns -n
# makedns   $new_node_name_xcat ## 这个命令无法运行成功

nodeset ${compute_prefix}${node_max} osimage=${image_choose}
### update clustershell conf ### 
nodes_name=($(nodels | grep ${compute_prefix} | sed 's/'"${compute_prefix}"'//g' | sort -n))
Nodes=${compute_prefix}[${nodes_name[0]}-${nodes_name[-1]}]
perl -ni -e 'if(/^compute/){print "compute: '${Nodes}'\n"}else{print}' /etc/clustershell/groups.d/local.cfg
