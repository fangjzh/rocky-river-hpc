#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置cluster shell - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
#### Install ClusterShell
yum -y -q install clustershell
# Setup node definitions
cd /etc/clustershell/groups.d
cat local.cfg > local.cfg.orig
echo "adm: ${sms_name}" > local.cfg
echo "compute: nonode" >> local.cfg   #### 添加节点时需要更改
echo "all: @adm,@compute" >> local.cfg
cd ~
######

echo "-->执行 $0 : 安装设置cluster shell 完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
