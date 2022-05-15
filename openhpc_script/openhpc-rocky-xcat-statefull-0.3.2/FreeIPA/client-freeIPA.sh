## client
##

## 设置一下域名之类的
if [ -n "$1" ] ; then
export sms_eth_internal=ens34

export sms_name=magi
export cnode_name=cnode01
export sms_ip=10.0.0.4
export cnode_ip=10.0.0.5
export domain_name=buildhpc.org

export internal_netmask=255.255.255.0
export internal_netmask_l=24

nmcli conn mod ${sms_eth_internal} ipv4.address ${cnode_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${cnode_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${cnode_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli conn mod ${sms_eth_internal} autoconnect yes
nmcli conn up ${sms_eth_internal}

#########change server name#########
echo ${cnode_name} > /etc/hostname
echo "${sms_ip}  ${sms_name}.${domain_name}  ${sms_name}" >>/etc/hosts
echo "${cnode_ip}  ${cnode_name}.${domain_name}  ${cnode_name}" >>/etc/hosts
nmcli g hostname ${cnode_name}
fi

########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##

###disable ipv6####
#echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
#sysctl -p /etc/sysctl.conf


dnf module -y install idm:DL1/client

ipa-client-install --hostname=cnode01.buildhpc.org  --mkhomedir  --server=magi.buildhpc.org  --domain example.com  --realm EXAMPLE.COM --password 3Pknj7niorIYupjlq7e0ZtX

## 不要选择no....   目前是成功的，但是不能禁止IPV6



