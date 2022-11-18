#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置NTP服务 - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
######set ntp server########
yum -y -q install chrony
systemctl enable chronyd.service
echo "server ntp1.aliyun.com iburst " >> /etc/chrony.conf 
echo "server ntp.ntsc.ac.cn iburst" >> /etc/chrony.conf
echo "allow ${sms_ip}/${internal_netmask_l}" >> /etc/chrony.conf   
perl -pi -e "s/#local\ stratum/local\ stratum/" /etc/chrony.conf   
systemctl restart chronyd 
## about chrony: https://www.cnblogs.com/my-show-time/p/14658895.html
####

echo "-->执行 $0 : 安装设置NTP服务完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
