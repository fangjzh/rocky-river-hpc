#!/bin/bash

source ./env.sh

### 修复网卡名称 ###
if [ ! -e /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal} ] ; then
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
nmcli conn mod ${sms_eth_internal} autoconnect yes
nmcli conn up ${sms_eth_internal}

if [ $? != 0 ]; then
echo "network error!"
exit
fi

###设置时区###
# timedatectl list-timezones
timedatectl set-timezone Asia/Shanghai
# timedatectl set-local-rtc 0
# timedatectl set-time "2021-08-21 18:29:30"
#  hwclock -w

#########change server name#########
echo ${sms_name} > /etc/hostname
## foreman is strict with the following line
echo "${sms_ip}  ${sms_name}.${domain_name}  ${sms_name}" >>/etc/hosts
nmcli g hostname ${sms_name}


########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##

yum -y -q install https://yum.puppet.com/puppet6-release-el-8.noarch.rpm
dnf module reset ruby
dnf module enable ruby:2.7
yum -y -q install https://yum.theforeman.org/releases/2.5/el8/x86_64/foreman-release.rpm
yum -y -q install foreman-installer

cp -r /boot/efi/EFI/rocky  /boot/efi/EFI/redhat

foreman-installer --enable-foreman-proxy \
                  --foreman-proxy-tftp=true \
                  --foreman-proxy-tftp-servername=${sms_ip} \
                  --foreman-proxy-tftp-managed true \
                  --foreman-proxy-dhcp=true \
                  --foreman-proxy-dhcp-managed true \
                  --foreman-proxy-dhcp-interface=${sms_eth_internal} \
                  --foreman-proxy-dhcp-gateway=${sms_ip} \
                  --foreman-proxy-dns true \
                  --foreman-proxy-dns-managed true \
                  --foreman-proxy-dns-forwarders "114.114.114.114; 8.8.4.4" \
                  --foreman-proxy-dns-interface "${sms_eth_internal}" \
                  --foreman-proxy-dns-reverse "140.168.192.in-addr.arpa" \
                  --foreman-proxy-dns-server "127.0.0.1" \
                  --foreman-proxy-dns-zone "local" 

# export sms_eth_externel=ens33
# export sms_subnet=$(echo ${sms_ip} | awk -F. '{print $1 "." $2 "." $3 ".0"}') 

echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -F
iptables -t nat -A POSTROUTING -s ${sms_subnet}/${internal_netmask_l} -o ${sms_eth_externel} -j MASQUERADE


## output info ##
# Executing: foreman-rake upgrade:run
#   Success!
#   * Foreman is running at https://cjhpc.local
#       Initial credentials are admin / 7jDtz639EMYAL8Tn
#   * Foreman Proxy is running at https://cjhpc.local:8443
# 
#   The full log is at /var/log/foreman-installer/foreman.log
##################

## dnf install dhcp-server

# ip_1=$(echo ${sms_ip} | awk -F. '{print $1 "." $2 "." $3 ".101"}')
# ip_2=$(echo ${sms_ip} | awk -F. '{print $1 "." $2 "." $3 ".200"}')
# 
# foreman-installer \
# --enable-foreman-proxy \
# --foreman-proxy-tftp=true \
# --foreman-proxy-tftp-servername=${sms_ip} \
# --foreman-proxy-tftp-managed true \
# --foreman-proxy-dhcp=true \
# --foreman-proxy-dhcp-managed true \
# --foreman-proxy-dhcp-interface=${sms_eth_internal} \
# --foreman-proxy-dhcp-gateway=${sms_ip} \
# --foreman-proxy-dhcp-range="${ip_1} ${ip_2}"
# 
# 
# systemctl start tftp
# systemctl start tftp.socket