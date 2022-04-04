## 红帽官方不推荐这个，搞到最后还是不搞为好
echo "not recommend in rhle 8 exit......"
exit 


yum -y -q install openldap openldap-clients openldap-devel nss-pam-ldapd
systemctl stop sssd
systemctl disable sssd
mkdir -p /opt/openldap/etc/cacerts
sed -i 's/dc=example,dc=com/dc=cjhpc,dc=local/g;s/#tls_cacertdir/tls_cacertdir\ \/opt\/openldap\/etc\/cacerts\n#tls_cacertdir/g' /etc/nslcd.conf

## 在centos 8 里 /etc/pam.d/system-auth 是个软链，链接到/etc/authselect/system-auth
## 且这个也是authselect apply-changes自动生成的
perl -pi -e 'print"auth        sufficient                                   pam_ladp.so user_first_pass\n" if ($_ =~ /^auth/ and $_ =~ /pam_deny.so$/)'  /etc/pam.d/system-auth
perl -pi -e 'print"account     [default=bad success=ok user_unknown=ignore] pam_ladp.so\n" if ($_ =~ /^account/ and $_ =~ /pam_permit.so$/)'  /etc/pam.d/system-auth
perl -pi -e 'print"password    sufficient    pam_ldap.so use_authtok\n" if ($_ =~ /^password/ and $_ =~ /pam_deny.so$/)'  /etc/pam.d/system-auth
perl -pi -e 'print"session     optional      pam_ldap.so\n" if ($_ =~ /^session/ and $_ =~ /pam_unix.so$/)'  /etc/pam.d/system-auth

sed -i 's/pam_deny.so/pam_deny.so\nauth\ sufficient\ pam_ladp.so user_first_pass/g'  /etc/pam.d/system-auth

cat <<EOF > /etc/sysconfig/authconfig
IPADOMAINJOINED=no
USEMKHOMEDIR=yes
USEPAMACCESS=no
CACHECREDENTIALS=yes
USESSSDAUTH=no
USESHADOW=yes
USEWINBIND=no
USEDB=no
PASSWDALGORITHM=yes
FORCELEGACY=yes
USEFPRINTD=yes
FORCESMARTCARD=no
USELDAPAUTH=yes
IPAV2NONTP=no
USEPASSWDQC=no
USELOCAUTHORIZE=yes
USECRACKLIB=yes
USEIPAV2=no
USEWINBINDAUTH=no
USESMARTCARD=no
USELDAP=yes
USENIS=no
USEKERBEROS=no
USESYSNETAUTH=yes
USESSSD=no
USEHESIOD=no
EOF

cat <<EOF > /etc/pam_ldap.conf
uri ldap://127.0.0.1/
ssl no
tls_cacertdir /opt/openldap/etc/cacerts
pam_password md5
EOF

## perl -n 和 -p区别是-p会自动打印,chomp 可以去掉换行符 chom可以去掉多个换行符
## 修改/etc/nsswitch.conf 在centos 8 里这个是authselect 自动生成的
perl -ni -e 'if ($_ =~ /^passwd:/ or $_ =~ /^shadow:/ or $_ =~ /^group:/ ) {chomp $_ ; print"$_ ldap\n"}  else {print"$_"} ' /etc/authselect/user-nsswitch.conf
authselect apply-changes