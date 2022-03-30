## first download the package from
## https://www.openldap.org/software/download/OpenLDAP/openldap-release
# wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz

yum -y -q install libtool-ltdl-devel  cyrus-sasl-devel ##cyrus-sasl-ldap 
## install process
tar -xvzf openldap-2.6.1.tgz
cd openldap-2.6.1
./configure --prefix=/opt/openldap --with-tls=openssl --with-cyrus-sasl
make depend
make
## 如果改了配置文件，一定要重新解压再编译，以免后边出现lib软链错误
## if the prefix folder already have files, remove it before make install
make install
cd /root


## add ldap user
useradd -r -s /sbin/nologin -d /opt/openldap/etc/slapd.d -m ldapd
mkdir -p /opt/openldap/etc/slapd.d
chown ldapd.ldapd /opt/openldap/etc/slapd.d
chmod 700 /opt/openldap/etc/slapd.d

##  这是由/opt/openldap/etc/openldap/slapd.ldif 指定的
##  mdb 数据库的位置，后边的Manager用户都放在这个数据库里边
mkdir  -p /opt/openldap/var/openldap-data
chown ldapd.ldapd  /opt/openldap/var/openldap-data
chmod 700  /opt/openldap/var/openldap-data

### 
# sudo -V |  grep -i "ldap"
## results should be
### ...
### ldap.conf path: /etc/sudo-ldap.conf
### ldap.secret path: /etc/ldap.secret
## if it is ok
# rpm -ql sudo-1.8.29-7.el8_4.1.x86_64 | grep -i schema.OpenLDAP
# cp /usr/share/doc/sudo/schema.OpenLDAP /opt/openldap/etc/openldap/schema/sudo.schema
cp `rpm -ql sudo | grep -i schema.OpenLDAP` /opt/openldap/etc/openldap/schema/sudo.schema

## convert schema to ldif
export PATH=/opt/openldap/sbin:$PATH 
chmod +x ./schema2ldif.sh
./schema2ldif.sh /opt/openldap/etc/openldap/schema/sudo.schema
cp ./sudo.ldif /opt/openldap/etc/openldap/schema

#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/cosine.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/nis.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/nis.ldif/' /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/cosine.ldif/' /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/sudo.ldif/' /opt/openldap/etc/openldap/slapd.ldif

mypass=`slappasswd -s '78g*tw23.ysq'`
perl -pi -e 's/secret/'${mypass}'/' /opt/openldap/etc/openldap/slapd.ldif

## 在初始配置之后，启动服务了还可以导入schema么？可以的
## /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/sudo.ldif

## 加入"dn: olcDatabase=config,cn=config"
## 不写的话默认产生olcDatabase={0}config的
## olcAccess项会导致无法修改config

perl -pi -e 's/rootdn can always read and write EVERYTHING!/

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcRootDN: cn=Manager,dc=cjhpc,dc=local

/' /opt/openldap/etc/openldap/slapd.ldif
## 这里似乎不能写olcRootPW

sed -i 's/dc=my-domain/dc=cjhpc/g;s/dc=com/dc=local/g' /opt/openldap/etc/openldap/slapd.ldif
# su ldapd -c "/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif"
# return error "This account is currently not available", because ldapd user is nologin in /etc/passwd
/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif
chown -R ldapd.ldapd /opt/openldap/etc/slapd.d
chown -R ldapd.ldapd /opt/openldap/var/run/

## 强行vi修改 /opt/openldap/etc/slapd.d 里的文件需要重启服务才能生效

## make service file
cat <<EOF  > /etc/systemd/system/slapd.service
[Unit]
Description=OpenLDAP Server Daemon
After=syslog.target network-online.target
Documentation=man:slapd
Documentation=man:slapd-mdb

[Service]
User=ldapd
Group=ldapd
Type=forking
PIDFile=/opt/openldap/var/run/slapd.pid
Environment="SLAPD_URLS=ldap:/// ldapi:/// ldaps:///"
Environment="SLAPD_OPTIONS=-F /opt/openldap/etc/slapd.d"
ExecStart=/opt/openldap/libexec/slapd -u ldapd -g ldapd -h \${SLAPD_URLS} \${SLAPD_OPTIONS}

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload

systemctl start slapd

cat <<EOF > /opt/openldap/etc/openldap/new.ldif
dn: dc=cjhpc,dc=local
objectclass: dcObject
objectclass: organization
o: Example Company
dc: cjhpc

dn: cn=Manager,dc=cjhpc,dc=local
objectclass: organizationalRole
cn: Manager
EOF

ldapadd -x -D "cn=Manager,dc=cjhpc,dc=local" -W -f /opt/openldap/etc/openldap/new.ldif

