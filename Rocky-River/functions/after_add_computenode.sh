#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

if [ ! -e new_install.nodes ]; then
    echo "没有新配置的节点！"
    exit
else
    Nodes=($(cat new_install.nodes | awk '{print $2}'))
    if [ -z ${Nodes[0]} ]; then
        echo "没有新配置的节点！"
        exit
    fi
fi

. /etc/profile.d/xcat.sh

## 同步授权文件
Nodes_x=($(cat new_install.nodes | awk '{print $1}'))
xdcp ${Nodes_x[0]} /etc/munge/munge.key /etc/munge/munge.key
# pdcp -w ${Nodes[0]} /etc/munge/munge.key /etc/munge/munge.key

## 计算节点添加Intel 编译器module
## this command is ok 
pdsh -w ${Nodes[0]}  echo 'export MODULEPATH=\${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' \>\> /etc/profile.d/lmod.sh

## 强制时间同步
pdsh -w ${Nodes[0]}  chronyc -a makestep

## 刷新节点状态
systemctl restart slurmctld
pdsh -w ${Nodes[0]} systemctl restart munge
pdsh -w ${Nodes[0]} systemctl restart slurmd

scontrol update NodeName=${Nodes[0]} State=RESUME

rm new_install.nodes