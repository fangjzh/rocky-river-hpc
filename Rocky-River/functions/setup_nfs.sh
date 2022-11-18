#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置nfs - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
# Disable /tftpboot and /install export entries
perl -pi -e "s|/tftpboot|#/tftpboot|" /etc/exports
perl -pi -e "s|/install|#/install|" /etc/exports
### note: fsid should be uniq, if add dir###
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports
##echo "/opt/repo *(ro,no_subtree_check,fsid=12)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
systemctl enable nfs-server

echo "-->执行 $0 : 安装设置nfs完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
