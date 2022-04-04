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
cat <<EOF > /opt/openldap/etc/openldap/addAccess.ldif 
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by * read
EOF
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f /opt/openldap/etc/openldap/addAccess.ldif 

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


#########
#####   这一段简直太罗嗦了。。。。。。 直接产生一个文件多好。。。。。
#########
## 接下来我们来产生一个user 和 group的 ldif 例子
#useradd -s /bin/bash -M testuser 
echo "testuser:x:1002:1002::/home/testuser:/bin/bash" > adduser.tmp
/usr/share/migrationtools/migrate_passwd.pl adduser.tmp | sed 's/dc=padl,dc=com/dc=cjhpc,dc=local/g'> adduser.ldif
perl -ni -e 'if ($_ =~ /^userPassword:/ ) {print"objectClass: shadowAccount\n$_"} elsif ($_ =~ /shadowAccount$/ ) { } else {print"$_"} ' adduser.ldif
## 密码 userPassword: {crypt}字段后边如果只有一个字符，在 无法编辑
perl -ni -e 'if ($_ =~ /{crypt}/){print "userPassword: {crypt}!!\n"} else{print} '  adduser.ldif
## 去除空行
perl -ni -e 'if ($_ =~ /^$/ or $_ =~ /^\ +$/){}else{print $_}' adduser.ldif
cat <<EOF >>  adduser.ldif
shadowLastChange: 19074
shadowMin: 0
shadowMax: 99999
shadowWarning: 7
gecos: testuser
EOF
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f adduser.ldif
echo "testuser:x:1002:" > addgroup.tmp
/usr/share/migrationtools/migrate_group.pl addgroup.tmp | sed 's/dc=padl,dc=com/dc=cjhpc,dc=local/g'> addgroup.ldif
perl -ni -e 'if ($_ =~ /{crypt}/){print "userPassword: {crypt}!!\n"} else{print} '  addgroup.ldif
/opt/openldap/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f addgroup.ldif
# 接下来可以在 Apache Directory Studio去复制粘贴了
# 右键 dc=cjhpc,dc=local下边的ou=People下边的uid=testuser，然后New Entry
# use exsiting entry as temple,选择默认 uid=testuser,ou=People,dc=cjhpc,dc=local
# 重复下一步，这样会建一个同级别的 entry

# 以上没有设置密码，在Apache Directory Studio设置CRYPT-SHA-512密码好像不管用
# Apache Directory Studio 学习视频 https://www.bilibili.com/video/av844671738/

## 红帽8已经放弃nslcd的方案了，所以还是用SSSD来搞
## 接下来配置SSSD 以及 ldap客户端
yum -y -q install openldap-clients sssd ## oddjob-mkhomedir

authselect select sssd with-mkhomedir
## 创建自定义的authselect 文件，-b应该是base,就是以默认sssd配置为基础创建
# authselect create-profile user-profile -b sssd
## 这样就创建了 /etc/authselect/custom/user-profile 配置文件夹
## 然后我们选择我们创建的这个
## authselect select sssd
# authselect select custom/user-profile

## 自定义nsswitch.conf，需要修改/etc/authselect/custom/user-profile/nsswitch.conf 
## 需要敲authselect apply-changes命令应用
# perl -ni -e 'if ($_ =~ /^passwd:/ or $_ =~ /^shadow:/ or $_ =~ /^group:/ ) {chomp $_ ; print"$_ ldap\n"}  else {print"$_"} ' /etc/authselect/custom/user-profile/nsswitch.conf
# authselect apply-changes

## 参考https://www.golinuxcloud.com/ldap-client-rhel-centos-8/
## https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/8/html/configuring_authentication_and_authorization_in_rhel/index
## 我们不用ssl 或者 slt 加密端口，所以也不要证书
## 我们暂时也不用sudo权限

## 备份配置文件，这是个牛逼用法，逗号表示分隔，然后{}里边的候选项一个是空的  一个是.original
cp -r /etc/pam.d{,.original}
cp /etc/authselect/user-nsswitch.conf{,.back`date +%Y%m%d-%H%M%S`}

## 似乎没有/etc/sssd/sssd.conf文件
## 参考 https://www.jianshu.com/p/8accfdb33725
## 这里有个例子 /usr/share/doc/sssd-common/sssd-example.conf
cat <<EOF > /etc/sssd/sssd.conf
[sssd]
config_file_version=2
services=nss,pam
domains=MyLDAP

[nss]
debug_level = 9
filter_groups = root
filter_users = root

[pam]

[domain/MyLDAP]
debug_level = 9
auth_provider = ldap
id_provider = ldap
chpass_provider = ldap
enumerate = false

ldap_schema = rfc2307
ldap_uri = ldap://127.0.0.1:389
ldap_search_base = dc=cjhpc,dc=local

access_provider = ldap
cache_credentials = True
# ldap_pwd_policy = shadow
filter_users = root

# access_filter这个参数尝试了很多种写法，网上众说纷纭，最后发现似乎不用，
# ldap_search_base+ ldap_user_name+ ldap_user_object_class就能定位搜索到用户信息了
# ldap_access_filter = (&(&(cn=unix)(memberUid=*)))
# ldap_access_filter = (&(objectclass=posixAccount))
# ldap_access_filter = "(&(cn=unix)(|(&(objectClass=posixGroup)(memberUid=*))))
# ldap_access_filter = (&(objectclass=person)(memberof=[basedn]))
# ldap_access_filter = memberof=[basedn]
# ldap_access_filter = (objectclass=person)
##### 这个可能是和ldap数据库里边的条目相关的，按实际情况修改
## 我用 migrationtools 导入的应该不用这些
# ldap_user_object_class = person
# ldap_user_uid_number = cn
# ldap_user_name = cn
#ldap_user_primary_group = primaryGroupID
#case_sensitive = false
#ldap_use_tokengroups = False
#use_fully_qualified_names = True

## 说明还是可以接入ldap的许可账号，我这里就不要了，因为可以匿名读取
# 接入账号
ldap_default_bind_dn =  cn=Manager,dc=cjhpc,dc=local
# 验证方式
ldap_default_authtok_type = password
# 密码
ldap_default_authtok = 78g*tw23.ysq

ldap_tls_cacertdir = /etc/openldap/certs
ldap_tls_reqcert = allow

#ldap_tls_reqcert = never

cache_credentials = True
ldap_tls_cacert = /etc/openldap/certs/laoshirenCA.pem
ldap_tls_reqcert = hard

ldap_id_use_start_tls = False
cache_credentials = True
entry_cache_timeout = 600
ldap_network_timeout = 3
EOF

## 上述文件里如果services = nss, pam, autofs，有何区别？ 

chmod 600 /etc/sssd/sssd.conf
systemctl enable --now sssd  ## 加--now应该是立即启动的意思
systemctl enable --now oddjobd
#systemctl restart sssd
## 

## 现在的问题，Apache Directory Studio 设置的密码无法登录，可能sssd本身不同步shadow的
## 看论坛留言应该是说 LDAP如果把shadow 共享起来非常不安全，所以SSSD 不存在这样的功能
## 那么我们的用户怎么同步呢，用ssh-key ?
id testuser ## 是可以看到结论的
getent passwd testuser ## 得到的字段第二个是*,表示它不能登录？
##这个表示不能用shadow认证，sssd默认不用这种传递shadow的模式？

## ssh-key ? 用户名和密码总得要的嘛
# ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
# cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
# chmod 0600 ~/.ssh/authorized_keys
# ssh-copy-id -i ~/.ssh/id_rsa.pub hadoo@ubuntu1
#####

## 如果只共享用户，本地又没有添加相关用户，那肯定不能登录呀

###  目前的问题是，sssd必须要用证书，不然就会报错
### sssd_be  Could not start TLS encryption. unsupported extended operation
### 所以现在去搞证书，不晓得证书和域名有没有关系？
## 参考：https://blog.csdn.net/u011607971/article/details/86153804

openssl genrsa -out laoshirenCA.key 2048
openssl req -x509 -new -nodes -key laoshirenCA.key -sha256 -days 1024 -out laoshirenCA.pem  -batch
## 不加 -batch会出现很多东西要填写
openssl genrsa -out laoshirenldap.key 2048
openssl req -new -key laoshirenldap.key -out laoshirenldap.csr -batch
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

## 测试
#ldapsearch -x -LLL uid
# netstat -nlp -t |grep slapd # 查看端口
# 查询用户信息，只能用389端口，636返回-1
ldapsearch -LLL -h localhost -p 389 -x -b "ou=People,dc=cjhpc,dc=local" -D "cn=Manager,dc=cjhpc,dc=local" -w  '78g*tw23.ysq' -s sub "uid=testuser"

# 参考 https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_authentication_and_authorization_in_rhel/configuring-sssd-to-use-ldap-and-require-tls-authentication_configuring-authentication-and-authorization-in-rhel
# 首先要下载证书
# mkdir -p  /etc/openldap/certs/
cp  /opt/openldap/etc/certs/laoshirenCA.pem  /etc/openldap/certs/

cp /etc/openldap/ldap.conf{,.back`date +%Y%m%d-%H%M%S`}

cat <<EOF >> /etc/openldap/ldap.conf
URI ldap://localhost:636
BASE dc=cjhpc,dc=local
TLS_CACERTDIR /etc/openldap/certs
TLS_CACERT /etc/openldap/certs/laoshirenCA.pem
TLS_REQCERT allow
EOF

## add 5 lines in /etc/sssd/sssd.conf
## ldap_tls_cacertdir = /etc/openldap/certs
## ldap_tls_reqcert = allow
## cache_credentials = True
## ldap_tls_cacert = /etc/openldap/certs/laoshirenCA.pem
## ldap_tls_reqcert = hard

systemctl restart sssd

getent passwd testuser

### 现在换了一种错误了
## Could not start TLS encryption. error:1416F086:SSL routines:tls_process_server_certificate:certificate verify fail
## routines:tls_process_server_certificate:certificate verify failed (self signed certificate)

## 测试命令
openssl s_client -connect localhost:636
## 提示错误
## Verification error: self signed certificate
openssl s_client -CAfile /etc/openldap/certs/laoshirenCA.pem -connect localhost:636
openssl verify /opt/openldap/etc/certs/laoshirenldap.crt

# 根据提示填写各个字段, 但注意 Common Name 最好是有效根域名(如 zeali.net ),
# 并且不能和后来服务器证书签署请求文件中填写的 Common Name 完全一样，否则会
# 导致证书生成的时候出现 error 18 at 0 depth lookup:self signed certificate 错误
# 自签名证书  似乎  无法正常工作。。。。 这是得放弃么？？？


