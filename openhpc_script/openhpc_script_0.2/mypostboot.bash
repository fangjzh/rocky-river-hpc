#!/bin/sh

export sms_ip=10.0.0.1

yum clean all 
yum makecache

perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

# Disable firewall for ${nodename}s
systemctl disable firewalld

# set dns 
echo "nameserver ${sms_ip}" >> /etc/resolv.conf

###install software into ${nodename} node ###
yum -y install ohpc-base-compute.x86_64 lmod-ohpc munge ohpc-slurm-client

systemctl  enable munge 
systemctl  enable slurmd
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" > /etc/sysconfig/slurmd


# Add Network Time Protocol (NTP) support
yum -y  install chrony
systemctl enable chronyd
systemctl start chronyd
# Identify master host as local NTP server
echo "server ${sms_ip}" >> /etc/chrony.conf

##################### add autofs #################################
yum -y install autofs
systemctl enable autofs
systemctl start autofs
##autofs ##
cat >/etc/auto.master<<'EOF'
/-     /etc/auto.pub  --timeout=1200
/home  /etc/auto.home   --timeout=1200
EOF
echo "/opt/ohpc/pub        ${sms_ip}:/opt/ohpc/pub" > /etc/auto.pub
echo "*    ${sms_ip}:/home/&" > /etc/auto.home
##################### add autofs  end #############################


# Update memlock settings within ${nodename} image, this is not wort with psh 
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
#####

# Enable ssh control via resource manager
echo "account required pam_slurm.so" >> /etc/pam.d/sshd
systemctl restart sshd