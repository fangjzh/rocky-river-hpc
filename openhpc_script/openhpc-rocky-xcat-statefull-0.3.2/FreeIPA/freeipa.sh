export sms_eth_internal=ens33

export sms_name=magi
export cnode_name=cnode01
export sms_ip=10.0.0.4
export cnode_ip=10.0.0.5
export domain_name=buildhpc.org

export internal_netmask=255.255.255.0
export internal_netmask_l=24

nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli conn mod ${sms_eth_internal} autoconnect yes
nmcli conn up ${sms_eth_internal}

#########change server name#########
echo ${sms_name} > /etc/hostname
echo "${sms_ip}  ${sms_name}.${domain_name}  ${sms_name}" >>/etc/hosts
echo "${cnode_ip}  ${cnode_name}.${domain_name}  ${cnode_name}" >>/etc/hosts
nmcli g hostname ${sms_name}

########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux

###do not disable ipv6####
#echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
#sysctl -p /etc/sysctl.conf

yum -y -q install chrony
systemctl enable chronyd.service
echo "server ntp1.aliyun.com iburst " >> /etc/chrony.conf 
echo "server ntp.ntsc.ac.cn iburst" >> /etc/chrony.conf
echo "allow ${sms_ip}/${internal_netmask_l}" >> /etc/chrony.conf   
perl -pi -e "s/#local\ stratum/local\ stratum/" /etc/chrony.conf   
systemctl restart chronyd 

dnf module enable idm:DL1  -y
dnf install ipa-server ipa-server-dns -y

#ipa-server-install -a secret12 --setup-dns  --reverse-zone=10.0.0.in-addr.arpa. --no-forwarders --hostname=${sms_name}.${domain_name} -r ${domain_name^^} -p secret12 -n ${domain_name} -U --ds-password 12345678 --admin-password 12345678
#ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} -r ${domain_name^^} -p secret12 -n ${domain_name} -U --ds-password 12345678 --admin-password 12345678
ipa-server-install -a secret12 --hostname=${sms_name}.${domain_name} -r EXAMPLE.COM -p secret12 -n example.com -U --ds-password 12345678 --admin-password 12345678
##--realm to provide the Kerberos realm name
##--ds-password to provide the password for the Directory Manager (DM), the Directory Server super user
##--admin-password to provide the password for admin, the IdM administrator
##--unattended to let the installation process select default options for the host name and domain nam
#########
### The IPA Master Server will be configured with:
### Hostname:       magi.buildhpc.org
### IP address(es): 10.0.0.4
### Domain name:    example.com
### Realm name:     EXAMPLE.COM
#########
### The CA will be configured with:
### Subject DN:   CN=Certificate Authority,O=EXAMPLE.COM
### Subject base: O=EXAMPLE.COM
### Chaining:     self-signed

##########################
## 修改LDAP admin 密码
## systemctl stop dirsrv@EXAMPLE-COM.service
## pwdhash 123456  ## 得到加密密码
## vi /etc/dirsrv/slapd-EXAMPLE-COM/dse.ldif
## 找到 nsslapd-rootpw,
##  替换相应字段

## Reset FreeIPA admin password 
#export LDAPTLS_CACERT=/etc/ipa/ca.crt
#ldappasswd -ZZ -D 'cn=Directory Manager' -W -S \
#uid=admin,cn=users,cn=accounts,dc=example,dc=com \
#-H ldap://magi.buildhpc.org

##  auto mk home dir
authconfig --enablemkhomedir --update


##ipa dnsrecord-add  buildhpc.org cnode01 --a-rec 10.0.0.5 
## ipa: ERROR: DNS is not configured

# if ipa: ERROR: did not receive Kerberos credentials
# kinit admin
ipa host-add cnode01.buildhpc.org --ip-address=10.0.0.5 --random 
# ipa-server-install --uninstall
## 得到密码