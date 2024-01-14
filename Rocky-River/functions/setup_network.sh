#!/bin/sh
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 设置网络 - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
### 修复网卡名称 ###
if [ ! -e /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal} ]; then
    echo "/etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal} is not exist!!!"
    exit
else
    perl -pi -e "s/NAME=.+/NAME=\"${sms_eth_internal}\"/" /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal}
    perl -pi -e "s/DEVICE=.+/DEVICE=${sms_eth_internal}/" /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal}
    nmcli c reload
fi

#########set internal interface####
nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli connection modify ${sms_eth_internal} ipv4.route-metric 199 
nmcli conn mod ${sms_eth_internal} autoconnect yes
nmcli conn up ${sms_eth_internal}


if [ $? != 0 ]; then
    echo "network error!"
    exit
fi

echo "-->执行 $0 : 设置网络完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
