## client
##  这个在server 执行也是可以的

##

## 设置一下域名之类的
export sms_eth_internal=ens33

export sms_name=cjhpc
export cnode_name=cnode01
export sms_ip=10.0.0.1
export cnode_ip=10.0.0.2
export domain_name=local

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


########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##


yum -y -q install openldap-clients sssd

cat <<EOF >> /etc/openldap/ldap.conf
URI ldap://cjhpc.local
BASE dc=cjhpc,dc=local
TLS_CACERTDIR /etc/openldap/certs
TLS_CACERT /etc/openldap/certs/laoshirenCA.pem
TLS_REQCERT allow
EOF

##  TLS_REQCERT allow 是的自己发给自己的证书也可以用
##  就是这个报错 tls_process_server_certificate:certificate verify failed (self signed certificate).
##  会导致认证服务终止

### 这里需要输入密码
scp  fang@cjhpc.local:/opt/openldap/etc/certs/laoshirenCA.pem  /etc/openldap/certs/

# 测试 -d 是debug
ldapsearch -H ldap://cjhpc.local -x -d 1 -b 'dc=cjhpc,dc=local' '(objectclass=*)'
## 测试
ldapsearch -x -ZZ

########################################
#######################################################
## 配置sssd

authselect select sssd with-mkhomedir


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
ldap_uri = ldap://cjhpc.local
ldap_search_base = dc=cjhpc,dc=local

## 从ldap里边取得访问权限#
## 这个要在ldapserver里设置允许从哪些域名、用户之类的访问
# access_provider = ldap 

access_provider = simple
#simple_allow_users = testuser
#simple_allow_groups = groupname


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
#ldap_tls_reqcert = hard

ldap_id_use_start_tls = False
cache_credentials = True
entry_cache_timeout = 600
ldap_network_timeout = 3
EOF

##  ldap_tls_reqcert = allow 使得自己发给自己的证书也可以用
##  就是这个报错 tls_process_server_certificate:certificate verify failed (self signed certificate).
##  会导致认证服务终止

## 上述文件里如果services = nss, pam, autofs，有何区别？ 



chmod 600 /etc/sssd/sssd.conf
systemctl enable --now sssd  ## 加--now应该是立即启动的意思
systemctl enable --now oddjobd


