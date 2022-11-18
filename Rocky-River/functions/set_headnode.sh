#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 头节点时区、hostname、防火墙设置 - - - - - - - -"

###设置时区###
# timedatectl list-timezones
timedatectl set-timezone Asia/Shanghai
# hwclock --verbose
# timedatectl set-local-rtc 0
# timedatectl set-ntp no
# timedatectl set-time "2021-08-21 18:29:30"
#  hwclock -w
# timedatectl set-ntp yes

#date -s `date -d -1day +%D`
#date -s `date -d -8hour +%T`
## 减去八小时的准确做法
# date -s "`date -d -1hour "+%F %T"`"

#########change server name#########
echo ${sms_name} >/etc/hostname
echo "${sms_ip}  ${sms_name}.${domain_name}  ${sms_name}" >>/etc/hosts
nmcli g hostname ${sms_name}

########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##

###disable ipv6####
echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Update memlock settings on master
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf

echo "-->执行 $0 : 头节点时区、hostname、防火墙设置完毕 + = + = + = + = + ="
echo "$0 执行完成！" >${0##*/}.log
