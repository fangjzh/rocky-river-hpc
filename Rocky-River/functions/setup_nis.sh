#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置nis - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
#####################         ###############################
## add nis server 
yum install -y -q rpcbind yp-tools ypbind ypserv >>${0##*/}.log 2>&1
systemctl enable rpcbind ypserv ypxfrd yppasswdd
##add ypdomainname
echo "NISDOMAIN=${domain_name}" >> /etc/sysconfig/network
systemctl start rpcbind ypserv ypxfrd yppasswdd
### update nis database 
sleep 6
echo y | /usr/lib64/yp/ypinit -m
sleep 6
###  ctrl-d to continue
systemctl restart rpcbind ypserv ypxfrd yppasswdd
###########

echo "-->执行 $0 : 安装设置nis 完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
