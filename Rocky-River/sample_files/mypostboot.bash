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
echo "nameserver ${sms_ip}" >>/etc/resolv.conf

###install software into ${nodename} node ###
yum -y -q install ohpc-base-compute.x86_64 lmod-ohpc munge ohpc-slurm-client

perl -pi -e "s/remote-fs.target.*/remote-fs.target network-online.target/" /usr/lib/systemd/system/slurmd.service
perl -pi -e 'print"Wants=network-online.target named.service\n" if $. == 4' /usr/lib/systemd/system/slurmd.service
systemctl daemon-reload

systemctl enable munge
systemctl enable slurmd
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" >/etc/sysconfig/slurmd

timedatectl set-timezone Asia/Shanghai
# Add Network Time Protocol (NTP) support
##### it has been listed in /opt/xcat/share/xcat/install/rocky/compute.rocky8.pkglist
# yum -y  install chrony
# systemctl enable chronyd
# # Identify master host as local NTP server
# echo "server ${sms_ip} iburst" >> /etc/chrony.conf
# systemctl restart chronyd

##################### add autofs #################################
yum -y -q install autofs
systemctl enable autofs

##autofs ##
cat >/etc/auto.master <<'EOF'
/-     /etc/auto.pub  --timeout=1200
/home  /etc/auto.home   --timeout=1200
EOF
echo "/opt/ohpc/pub        ${sms_ip}:/opt/ohpc/pub" >/etc/auto.pub
echo "*    ${sms_ip}:/home/&" >/etc/auto.home

systemctl restart autofs
##################### add autofs  end #############################

# Update memlock settings within ${nodename} image, this is not wort with psh
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf
#####

# Enable ssh control via resource manager
echo "account required pam_slurm.so" >>/etc/pam.d/sshd
systemctl restart sshd

####
yum install -y -q rpcbind yp-tools ypbind authconfig
systemctl enable rpcbind ypbind
echo "NISDOMAIN=${domain_name}" >>/etc/sysconfig/network

echo "# generated by /sbin/dhclient-script" >/etc/yp.conf
echo "domain ${domain_name} server ${sms_ip}" >>/etc/yp.conf

###
authconfig --update --enablenis

###
systemctl restart rpcbind ypbind

### 这一段在计算节点上运行即可监控计算节点，注意计算节点要时间同步
telegraf=1
if [ ! $telegraf ]; then

    cat <<EOF >/etc/systemd/system/telegraf.service
[Unit]
Description="telegraf"
After=network.target

[Service]
Type=simple

ExecStart=/opt/ohpc/pub/apps/telegraf/telegraf --config telegraf.conf
WorkingDirectory=/opt/ohpc/pub/apps/telegraf

SuccessExitStatus=0
LimitNOFILE=65536
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=telegraf
KillMode=process
KillSignal=SIGQUIT
TimeoutStopSec=5
Restart=always


[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable telegraf
    systemctl restart telegraf
    systemctl status telegraf

fi
