#!/bin/sh

export sms_ip=10.0.0.1
export domain_name=local
export sms_name=cjhpc


perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/local-*.repo
wget -O /etc/yum.repos.d/compute_node.repo http://${sms_ip}:80//opt/repo/compute_node.repo
yum clean all 
yum makecache

# Disable firewall for ${nodename}s
systemctl disable firewalld

# set dns 
echo "nameserver ${sms_ip}" >> /etc/resolv.conf

###install software into ${nodename} node ###
yum -y install ohpc-base-compute.x86_64 lmod-ohpc munge ohpc-slurm-client

systemctl  enable munge 
systemctl  enable slurmd
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" > /etc/sysconfig/slurmd


timedatectl set-timezone Asia/Shanghai
# Add Network Time Protocol (NTP) support
##### it has been listed in /opt/xcat/share/xcat/install/rocky/compute.rocky8.pkglist
# yum -y  install chrony
# systemctl enable chronyd
# # Identify master host as local NTP server
# echo "server ${sms_ip} iburst" >> /etc/chrony.conf
# systemctl restart chronyd

##################### add autofs #################################
yum -y install autofs
systemctl enable autofs

##autofs ##
cat >/etc/auto.master<<'EOF'
/-     /etc/auto.pub  --timeout=1200
/home  /etc/auto.home   --timeout=1200
EOF
echo "/opt/ohpc/pub        ${sms_ip}:/opt/ohpc/pub" > /etc/auto.pub
echo "*    ${sms_ip}:/home/&" > /etc/auto.home

systemctl restart autofs
##################### add autofs  end #############################


# Update memlock settings within ${nodename} image, this is not wort with psh 
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
#####

# Enable ssh control via resource manager
echo "account required pam_slurm.so" >> /etc/pam.d/sshd
systemctl restart sshd


#### 
yum install -y rpcbind yp-tools ypbind  authconfig
systemctl enable rpcbind ypbind
echo "NISDOMAIN=${domain_name}" >> /etc/sysconfig/network

echo "# generated by /sbin/dhclient-script" >/etc/yp.conf
echo "domain ${domain_name} server ${sms_ip}" >>/etc/yp.conf

###
authconfig --update --enablenis

###
systemctl restart rpcbind ypbind


#### install n9e-agentd
sleep 2

mkdir -p /opt/n9e
cd /opt/n9e
##wget 116.85.64.82/n9e-agentd-5.0.0-rc8.tar.gz
wget http://${sms_ip}:80//opt/repo/other/n9e-agentd-5.0.0-rc8.tar.gz
tar zxf n9e-agentd-5.0.0-rc8.tar.gz
rm -f n9e-agentd-5.0.0-rc8.tar.gz

perl -pi -e "s/localhost/${sms_ip}/" /opt/n9e/agentd/etc/agentd.yaml
/bin/cp /opt/n9e/agentd/systemd/n9e-agentd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable n9e-agentd
systemctl restart n9e-agentd
##systemctl status n9e-agentd
