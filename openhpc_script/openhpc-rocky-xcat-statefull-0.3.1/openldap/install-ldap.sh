## first download the package from
## https://www.openldap.org/software/download/OpenLDAP/openldap-release
# wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz

systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux

yum -y -q install gcc make libtool-ltdl-devel  cyrus-sasl-devel  openssl-devel # systemd-devel perl-devel #openssl ##cyrus-sasl-ldap 
## install process
tar -xvzf openldap-2.6.1.tgz
cd openldap-2.6.1
## ./configure --prefix=/opt/openldap --disable-static \
## --enable-debug --with-tls=openssl --with-cyrus-sasl --enable-dynamic \
## --enable-crypt --enable-spasswd --enable-slapd --enable-modules \
## --enable-rlookups --enable-backends=mod --disable-sql \
## --enable-overlays=mod --enable-wt=no --with-systemd --enable-mdb
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
cat <<EOF  > /etc/systemd/system/slapd.service
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

## add ppolicy schema, 在tests文件夹里的ppolicy.ldif似乎并不是schema文件，所以那里去了？ 
## ppolicy.ldif 应该是不需要了，编译完成就会有，在2.4版本里有这个文件，但是和tests文件夹里边的不是一回事
## tests文件夹下边的应该是一个具体的策略配置
## 那么，
### /bin/cp /root/openldap-2.6.1/tests/data/ppolicy.ldif /opt/openldap/etc/openldap/schema
# cat /root/openldap-2.6.1/tests/data/ppolicy.ldif | awk 'NR>7{print $0}' > /opt/openldap/etc/openldap/schema/ppolicy.ldif
# sed -i 's/example/cjhpc/g;s/dc=com/dc=local/g' /opt/openldap/etc/openldap/schema/ppolicy.ldif
# /opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/schema/ppolicy.ldif

## 可不可以不用ldapi接口，直接slapadd -F? 
## /opt/openldap/sbin/slapadd -F /tmp/xxx -f /opt/openldap/etc/openldap/schema/schema/openldap.ldif
## 不行，这个命令还是只能在空文件夹产生文件


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

# need password  ？
# /opt/openldap/bin/ldapadd -x -D "cn=Manager,dc=cjhpc,dc=local" -W -f /opt/openldap/etc/openldap/new.ldif
## if access ctrl is added in slapd.d/cn\=config/olcDatabase\=\{1\}mdb.ldif as follow: 
##olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external
## ,cn=auth manage by * break
## then restart slapd, passowrd is not needed.
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/new.ldif

## migrationtools 可以直接下载rpm包，然后解压，把解压到的migrationtools 文件夹拷贝到/usr/share/，并且给里边的脚本以执行权限
## wget http://mirror.centos.org/centos/7/os/x86_64/Packages/migrationtools-47-15.el7.noarch.rpm
## 实测是可以用的
if [ -e ./migrationtools.tgz ] ; then
  tar -xvzf ./migrationtools.tgz -C /usr/share
fi
## migrationtools 产生的文件还需要替换一些字段（dc=xxx,dc=com）才能正确导入

## 接下来配置SSSD 以及 ldap客户端
yum -y -q install openldap-clients sssd
authselect select sssd
perl -ni -e 'if ($_ =~ /^passwd:/ or $_ =~ /^shadow:/ or $_ =~ /^group:/ ) {chomp $_ ; print"$_ ldap\n"}  else {print"$_"} ' /etc/authselect/user-nsswitch.conf
authselect apply-changes
