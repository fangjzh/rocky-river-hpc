#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

## clustershell不是必要的，xcat已经包含了相关功能

echo "-->执行 $0 : 安装设置cluster shell - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
i_fold=$(pwd)
#### Install ClusterShell
yum -y -q install clustershell
# Setup node definitions
cp /etc/clustershell/groups.d/local.cfg{,.orig}
#cd /etc/clustershell/groups.d
echo "adm: ${sms_name}" > /etc/clustershell/groups.d/local.cfg
echo "compute: nonode" >> /etc/clustershell/groups.d/local.cfg   #### 添加节点时需要更改
echo "all: @adm,@compute" >> /etc/clustershell/groups.d/local.cfg
cd ~
######

cd $i_fold
echo "-->执行 $0 : 安装设置cluster shell 完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
