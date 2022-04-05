## 测试在rocky linux 8.5 中进行，两台虚拟机
## 网卡都是两个 桥接+内部网络
#参考：
#https://www.golinuxcloud.com/configure-openldap-with-tls-certificates/
#https://www.golinuxcloud.com/ldap-client-rhel-centos-8/

## 设置一下域名之类的
export sms_eth_internal=ens33

export sms_name=cjhpc
export cnode_name=cnode01
export sms_ip=10.0.0.1
export cnode_ip=10.0.0.2
export domain_name=local

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
### need reboot ##

nowdir=`pwd`

wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz

if [ -e ./openldap-2.6.1.tgz ] ; then
echo "find openldap-2.6.1.tgz, continue...."
else
echo "no openldap-2.6.1.tgz, exit ....."
fi

yum -y -q install gcc make libtool-ltdl-devel  cyrus-sasl-devel  openssl-devel # systemd-devel perl-devel #openssl ##cyrus-sasl-ldap 
## install process
tar -xvzf openldap-2.6.1.tgz
cd openldap-2.6.1

./configure --prefix=/opt/openldap --with-tls=openssl --with-cyrus-sasl --enable-ppolicy  --enable-spasswd 
##  --enable-spasswd 可以支持SASL认证，在slapd.ldif里边指定密码类型么？
## 参考 https://www.openldap.org/doc/admin24/sasl.html#DIGEST-MD5
## 似乎有些复杂，先不整了
make depend
make
make install
cd ..
## ############
export PATH=/opt/openldap/sbin:$PATH

### add ldap user
useradd -r -s /sbin/nologin -d /opt/openldap/var -m ldapd
mkdir -p /opt/openldap/etc/slapd.d

#####
mkdir  -p /opt/openldap/var/openldap-data
chown -R ldapd.ldapd  /opt/openldap/var/openldap-data
chmod 700  /opt/openldap/var/openldap-data

if [ -e ./slapd.ldif ] ; then
echo "find slapd.ldif, continue...."
else
echo "no slapd.ldif, exit ....."
fi

#mypass=`slappasswd -s '78g*tw23.ysq'`  ### 这条命令每次生成的字符串不一样，而且有特殊字符

# sed -i 's/dc=my-domain/dc=cjhpc/g;s/dc=com/dc=local/g' ./slapd.ldif

/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l ./slapd.ldif
chown -R ldapd.ldapd /opt/openldap/etc/slapd.d
chown -R ldapd.ldapd /opt/openldap/var/run/
chown -R ldapd.ldapd  /opt/openldap/var/openldap-data

## 强行vi修改 /opt/openldap/etc/slapd.d 里的文件需要重启服务才能生效

## make service file 
## 这里太诡异了，LAPD_OPTIONS=-F/opt/openldap/etc/slapd.d
## -F 后边有空格就不能跑，而在shell里边有无空格都可以跑
## 也许在这个service里边这么写，LAPD_OPTIONS里边的内容被当成一个字符串
## 而不是两个分开的字符串
cat <<EOF  > /usr/lib/systemd/system/slapd.service
[Unit]
Description=OpenLDAP Server Daemon
After=syslog.target network-online.target
Documentation=man:slapd
Documentation=man:slapd-mdb

[Service]
Type=forking
PIDFile=/opt/openldap/var/run/slapd.pid
Environment="SLAPD_URLS=ldap:/// ldapi:/// ldaps:///"
Environment="SLAPD_OPTIONS=-F/opt/openldap/etc/slapd.d"
ExecStart=/opt/openldap/libexec/slapd -u ldapd -g ldapd -h \${SLAPD_URLS} \${SLAPD_OPTIONS}

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable slapd
systemctl start slapd

########################################################################
########################################################################
### 
# rpm -ql sudo-1.8.29-7.el8_4.1.x86_64 | grep -i schema.OpenLDAP
# cp /usr/share/doc/sudo/schema.OpenLDAP /opt/openldap/etc/openldap/schema/sudo.schema
cd $nowdir
sudo_schema=`rpm -ql sudo | grep -i schema.OpenLDAP`
if [ -e $sudo_schema ] ; then
  /bin/cp $sudo_schema /opt/openldap/etc/openldap/schema/sudo.schema
  ## convert schema to ldif   
  if [ -e ./schema2ldif.sh ] ; then
    chmod +x ./schema2ldif.sh
    ./schema2ldif.sh /opt/openldap/etc/openldap/schema/sudo.schema
    /bin/cp ./sudo.ldif /opt/openldap/etc/openldap/schema
    /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/sudo.ldif
  fi
fi

yum -y -q install openssh-ldap  
ssh_schema_ldif=`rpm -ql openssh-ldap | grep -i openldap.ldif`
if [ -e $ssh_schema_ldif ] ; then
  /bin/cp $ssh_schema_ldif /opt/openldap/etc/openldap/schema/openssh-lpk-openldap.ldif
  /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/openssh-lpk-openldap.ldif
fi

## 在初始配置之后，启动服务了还可以导入schema么？可以的
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/inetorgperson.ldif

### add account base entry
cat <<EOF > /opt/openldap/etc/openldap/base_entry.ldif
dn: dc=cjhpc,dc=local
objectclass: dcObject
objectclass: organization
o: Example Company
dc: cjhpc

dn: cn=Manager,dc=cjhpc,dc=local
objectclass: organizationalRole
cn: Manager

dn: ou=People,dc=cjhpc,dc=local
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=cjhpc,dc=local
objectClass: organizationalUnit
ou: Group
EOF

/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/base_entry.ldif

### add test user
cat <<EOF > /opt/openldap/etc/openldap/new_user_group.ldif
dn: cn=testuser,ou=Group,dc=cjhpc,dc=local
objectClass: posixGroup
objectClass: top
cn: testuser
userPassword: {crypt}!!
gidNumber: 1002

dn: uid=testuser,ou=People,dc=cjhpc,dc=local
uid: testuser
cn: testuser
objectClass: account
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
userPassword: {crypt}!!
loginShell: /bin/bash
uidNumber: 1002
gidNumber: 1002
homeDirectory: /home/testuser
shadowLastChange: 19074
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
gecos: testuser
EOF

/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/new_user_group.ldif

########################################################################
########################################################################
### 证书部署
openssl genrsa -out laoshirenCA.key 2048
openssl req -x509 -new -nodes -key laoshirenCA.key -sha256 -days 1024 -out laoshirenCA.pem   -subj  "/CN=cnode01.local" #-batch 
## 不加 -batch或者域名会出现很多东西要填写
## 两个域名要不一样，不然ssl会报错 tls_process_server_certificate:certificate verify failed (self signed certificate).
openssl genrsa -out laoshirenldap.key 2048
openssl req -new -key laoshirenldap.key -out laoshirenldap.csr -subj "/CN=cjhpc.local" # -batch # 
openssl x509 -req -in laoshirenldap.csr -CA laoshirenCA.pem -CAkey laoshirenCA.key -CAcreateserial -out laoshirenldap.crt -days 1460 -sha256

mkdir -p /opt/openldap/etc/certs
/bin/cp laoshirenldap.{crt,key} laoshirenCA.pem /opt/openldap/etc/certs
chown -R ldapd:ldapd /opt/openldap/etc/certs

# 按照此顺序（报错时切换顺序尝试 ）
# 注意权限如果有问题也会出错，因为默认的laoshirenldap.key 是 -rw-------，只有所有者才能读取
cat <<EOF > certs.ldif
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /opt/openldap/etc/certs/laoshirenCA.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /opt/openldap/etc/certs/laoshirenldap.key

dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /opt/openldap/etc/certs/laoshirenldap.crt
EOF

/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f  certs.ldif

## 测试
## ldapsearch  -D 'cn=Manager,dc=cjhpc,dc=local' -w 78g*tw23.ysq -ZZ

## 添加数据库匿名访问权限 
cat <<EOF > ./addAccess.ldif 
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to *  by self write by anonymous auth by * read
EOF
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f ./addAccess.ldif  
## 这个olcAccess 是有顺序的，先写的生效，比如这里匿名用户被授权“认证”，虽然匿名用户也在by * read 里边，

