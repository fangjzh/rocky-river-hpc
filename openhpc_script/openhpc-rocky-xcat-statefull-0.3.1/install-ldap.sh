## install migrationtools
wget https://rpmfind.net/linux/centos/7.9.2009/os/x86_64/Packages/migrationtools-47-15.el7.noarch.rpm
rpm -ivh migrationtools-47-15.el7.noarch.rpm
## first download the package from
## https://www.openldap.org/software/download/OpenLDAP/openldap-release
wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.1.tgz

yum -y -q install libtool-ltdl-devel  cyrus-sasl-ldap cyrus-sasl-devel
## install process
tar -xvzf openldap-2.6.1.tgz
cd openldap-2.6.1
./configure --prefix=/opt/openldap --disable-static \
--enable-debug --with-tls=openssl --with-cyrus-sasl --enable-dynamic \
--enable-crypt --enable-spasswd --enable-slapd --enable-modules \
--enable-rlookups --enable-backends=mod --disable-sql \
--enable-overlays=mod --enable-wt=no
make depend
make
## if the prefix folder already have files, remove it before make install
make install

## add ldap user
useradd -r -s /sbin/nologin -d /opt/openldap/etc/slapd.d -m ldapd
mkdir -p /opt/openldap/etc/slapd.d
chown ldapd.ldapd /opt/openldap/etc/slapd.d
chmod 700 /opt/openldap/etc/slapd.d

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


#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/cosine.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
#perl -pi -e 'print"include: file:///opt/openldap/etc/openldap/schema/nis.ldif\n" if ($_ =~ /core.ldif$/)'  /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/nis.ldif/' /opt/openldap/etc/openldap/slapd.ldif
perl -pi -e 's/core.ldif/core.ldif\ninclude:\ file:\/\/\/opt\/openldap\/etc\/openldap\/schema\/cosine.ldif/' /opt/openldap/etc/openldap/slapd.ldif

sed -i 's/dc=my-domain/dc=cjhpc/g;s/dc=com/dc=local/g' /opt/openldap/etc/openldap/slapd.ldif
# su ldapd -c "/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif"
# return error "This account is currently not available", because ldapd user is nologin in /etc/passwd
/opt/openldap/sbin/slapadd -n 0 -F /opt/openldap/etc/slapd.d -l /opt/openldap/etc/openldap/slapd.ldif
chown -R ldapd.ldapd /opt/openldap/etc/slapd.d
chown -R ldapd.ldapd /opt/openldap/var/run/

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

