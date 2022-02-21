##############################################################################
## now add components to ${nodename}-node
export sms_ip=10.0.0.3
export pacakge_dir=/root/
export nodename=cnode02

psh ${nodename} perl -pi -e '"s/enabled=1/enabled=0/"' /etc/yum.repos.d/\*.repo
psh ${nodename} wget -O /etc/yum.repos.d/compute_node.repo http://${sms_ip}:80//opt/repo/compute_node.repo
psh ${nodename} yum clean all


###install software into ${nodename} node ###
psh ${nodename} yum -y install ohpc-base-compute.x86_64
# Disable firewall for ${nodename}s
psh ${nodename} systemctl disable firewalld

#####install module environment #####
psh ${nodename} yum -y install lmod-ohpc

# Add Slurm client support meta-package
psh ${nodename} yum -y install munge ohpc-slurm-client
psh ${nodename} systemctl  enable munge 
psh ${nodename} systemctl  enable slurmd
psh ${nodename} echo SLURMD_OPTIONS="--conf-server ${sms_ip}" \> /etc/sysconfig/slurmd


# Add Network Time Protocol (NTP) support
psh ${nodename} yum -y  install chrony
psh ${nodename} systemctl enable chronyd
# Identify master host as local NTP server
##cd ${package_dir}
##echo "server ${sms_ip}" > ./chrony.conf
##pscp ./chrony.conf ${nodename}:/etc/
psh ${nodename}  echo "server ${sms_ip}" \>\> /etc/chrony.conf

##################### add autofs #################################
psh ${nodename} yum -y install autofs
psh ${nodename} systemctl enable autofs

##autofs ##
# pacakge_dir=/root/package
cd ${package_dir}
cat >./auto.master<<'EOF'
/-     /etc/auto.pub  --timeout=1200
/-     /etc/auto.repo  --timeout=1200
/home  /etc/auto.home   --timeout=1200
EOF
echo "/opt/ohpc/pub        ${sms_ip}:/opt/ohpc/pub" > ./auto.pub
echo "/opt/repo        ${sms_ip}:/opt/repo" > ./auto.repo
echo "*    ${sms_ip}:/home/&" > ./auto.home


## scp file , ${nodename} is node group ##
pscp ./auto.* ${nodename}:/etc/
##################### add autofs  end #################################


# Update memlock settings within ${nodename} image, this is not wort with psh 
psh ${nodename} perl -pi -e "'s/# End of file/\* soft memlock unlimited\n$&/s'" /etc/security/limits.conf
psh ${nodename} perl -pi -e "'s/# End of file/\* hard memlock unlimited\n$&/s'" /etc/security/limits.conf
#####

# Enable ssh control via resource manager
psh ${nodename}  echo "account required pam_slurm.so" \>\> /etc/pam.d/sshd

###### reboot the ${nodename} node ####
######        the ${nodename} node ####
######            ${nodename} node ####
######                    node ####
######                         ####

## xdcp ${nodename} /etc/slurm/slurm.conf /etc/slurm/slurm.conf
xdcp ${nodename} /etc/munge/munge.key /etc/munge/munge.key

#
# Create a sync file for pushing user credentials to the nodes
echo "MERGE:" > syncusers
echo "/etc/passwd -> /etc/passwd" >> syncusers
echo "/etc/group -> /etc/group" >> syncusers
echo "/etc/shadow -> /etc/shadow" >> syncusers
# Use xCAT to distribute credentials to nodes
xdcp ${nodename} -F syncusers