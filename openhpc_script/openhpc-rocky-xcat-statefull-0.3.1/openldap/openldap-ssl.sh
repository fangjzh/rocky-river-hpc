##
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

wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz

yum -y -q install gcc make libtool-ltdl-devel  cyrus-sasl-devel  openssl-devel # systemd-devel perl-devel #openssl ##cyrus-sasl-ldap 
## install process
tar -xvzf openldap-2.6.1.tgz
cd openldap-2.6.1

./configure --prefix=/opt/openldap --with-tls=openssl --with-cyrus-sasl --enable-ppolicy 
make depend
make
make install
cd /root
## make test 出错可能是事前没有make ^_^
## 如果改了配置文件，一定要重新解压再编译，以免后边出现lib软链错误
## if the prefix folder already have files, remove it before make install

## add ldap user
useradd -r -s /sbin/nologin -d /opt/openldap/var -m ldapd
mkdir -p /opt/openldap/etc/slapd.d


##  这是由/opt/openldap/etc/openldap/slapd.ldif 指定的
##  mdb 数据库的位置，后边的Manager用户都放在这个数据库里边
mkdir  -p /opt/openldap/var/openldap-data
chown -R ldapd.ldapd  /opt/openldap/var/openldap-data
chmod 700  /opt/openldap/var/openldap-data

/bin/cp /opt/openldap/etc/openldap/slapd.ldif.default /opt/openldap/etc/openldap/slapd.ldif
#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/cosine.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/nis.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/nis.ldif/' /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/cosine.ldif/' /opt/openldap/etc/openldap/slapd.ldif

export PATH=/opt/openldap/sbin:$PATH
### 
# sudo -V |  grep -i "ldap"
## results should be
### ...
### ldap.conf path: /etc/sudo-ldap.conf
### ldap.secret path: /etc/ldap.secret
## if it is ok
# rpm -ql sudo-1.8.29-7.el8_4.1.x86_64 | grep -i schema.OpenLDAP
# cp /usr/share/doc/sudo/schema.OpenLDAP /opt/openldap/etc/openldap/schema/sudo.schema
cd /root
sudo_schema=`rpm -ql sudo | grep -i schema.OpenLDAP`
if [ -e $sudo_schema ] ; then
  /bin/cp $sudo_schema /opt/openldap/etc/openldap/schema/sudo.schema
  ## convert schema to ldif   
  if [ -e ./schema2ldif.sh ] ; then
    chmod +x ./schema2ldif.sh
    ./schema2ldif.sh /opt/openldap/etc/openldap/schema/sudo.schema
    /bin/cp ./sudo.ldif /opt/openldap/etc/openldap/schema
    perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/sudo.ldif/' /opt/openldap/etc/openldap/slapd.ldif
  fi
fi

yum -y -q install openssh-ldap  
ssh_schema_ldif=`rpm -ql openssh-ldap | grep -i openldap.ldif`
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/usr\/share\/doc\/openssh-ldap\/openssh-lpk-openldap.ldif/' /opt/openldap/etc/openldap/slapd.ldif

mypass=`slappasswd -s '78g*tw23.ysq'`  ### 这条命令每次生成的字符串不一样，而且有特殊字符
mypass={SSHA}ehNE9DlisIY7rFt6Sf3DWMPVnUoqcRYe
perl -pi -e 's/secret/'${mypass}'/' /opt/openldap/etc/openldap/slapd.ldif


## 加入"dn: olcDatabase=config,cn=config"
## 不写的话默认产生olcDatabase={0}config的
## olcAccess项会导致无法修改config

perl -pi -e 's/rootdn can always read and write EVERYTHING!/

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break

/' /opt/openldap/etc/openldap/slapd.ldif
## 这里不能写olcRootPW,而写上olcRootDN: cn=Manager,dc=cjhpc,dc=local也没啥用

sed -i 's/dc=my-domain/dc=cjhpc/g;s/dc=com/dc=local/g' /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 'print"olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break\n"  if ($_ =~ /^olcSuffix:\ dc=cjhpc,dc=local/)' \
/opt/openldap/etc/openldap/slapd.ldif

# su ldapd -c "/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif"
# return error "This account is currently not available", because ldapd user is nologin in /etc/passwd
/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif
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

## 在初始配置之后，启动服务了还可以导入schema么？可以的
## /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/sudo.ldif
## /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /usr/share/doc/openssh-ldap/openssh-lpk-openldap.ldif
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/inetorgperson.ldif

## 添加数据库匿名访问权限 
##这里要改掉才行，不安全！！！！！！！！！！！！！！！！！！！！！
##这里要改掉才行，不安全！！！！！！！！！！！！！！！！！！！！！
cat <<EOF > /opt/openldap/etc/openldap/addAccess.ldif 
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by * read
EOF
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/addAccess.ldif 



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

### 证书部署
openssl genrsa -out laoshirenCA.key 2048
openssl req -x509 -new -nodes -key laoshirenCA.key -sha256 -days 1024 -out laoshirenCA.pem -batch # -subj  "/CN=127.0.0.1"
## 不加 -batch会出现很多东西要填写
openssl genrsa -out laoshirenldap.key 2048
openssl req -new -key laoshirenldap.key -out laoshirenldap.csr -batch # -subj "/CN=127.0.0.1"
openssl x509 -req -in laoshirenldap.csr -CA laoshirenCA.pem -CAkey laoshirenCA.key -CAcreateserial -out laoshirenldap.crt -days 1460 -sha256

mkdir -p /opt/openldap/etc/certs
chown -R ldapd:ldapd /opt/openldap/etc/certs
/bin/cp laoshirenldap.{crt,key} laoshirenCA.pem /opt/openldap/etc/certs

# 按照此顺序（报错时切换顺序尝试，就是上边生成各种证书的时间顺序 NB!）
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


