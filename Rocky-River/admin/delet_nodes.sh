#!/bin/sh

. /etc/profile.d/xcat.sh

if [ -z $1 ]; then
    echo "未输入节点信息，退出！"
    exit
fi

if [ -z ${sms_name} ]; then
    source ./env.text
fi

read -p "是否需要删除节点 $1 ：(y/n)  " ichoice
if [[ "$ichoice" == "y" ]]; then
    # makedns -d $1
    makehosts -d $1
    makedhcp -d $1
    rmdef -t node $1
    makedns -n
    ### update clustershell conf ### 
    sed -i "/^NodeName=${1}/d" /etc/slurm/slurm.conf
    ## current nodes in slurm
    nodes_name=($(nodels | grep ${compute_prefix} | sed 's/'"${compute_prefix}"'//g' | sort -n))
    sed -i '/^PartitionName=normal/d' /etc/slurm/slurm.conf
    if [ ! -z ${nodes_name[0]} ]; then
        Nodes=${compute_prefix}[${nodes_name[0]}-${nodes_name[-1]}]
        echo "PartitionName=normal Nodes=${Nodes} Default=YES MaxTime=168:00:00 State=UP Oversubscribe=YES" >>/etc/slurm/slurm.conf
    fi
    perl -ni -e 'if(/^compute/){print "compute: '${Nodes}'\n"}else{print}' /etc/clustershell/groups.d/local.cfg
    echo "已删除节点 $1 "
else
    echo "取消，退出"
fi
