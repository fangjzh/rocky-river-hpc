##############################################################################
## now add components to cnode02-node
export sms_ip=10.0.0.3
export pacakge_dir=/root/

psh cnode02 perl -pi -e '"s/enabled=1/enabled=0/"' /etc/yum.repos.d/\*.repo
psh cnode02 wget -O /etc/yum.repos.d/compute_node.repo http://${sms_ip}:80//opt/repo/compute_node.repo
psh cnode02 yum clean all


###install software into cnode02 node ###
psh cnode02 yum -y install ohpc-base-compute.x86_64
# Disable firewall for cnode02s
psh cnode02 systemctl disable firewalld

#####install module environment #####
psh cnode02 yum -y install lmod-ohpc

# Add Slurm client support meta-package
psh cnode02 yum -y install munge ohpc-slurm-client
psh cnode02 systemctl  enable munge 
psh cnode02 systemctl  enable slurmd
psh cnode02 echo SLURMD_OPTIONS="--conf-server ${sms_ip}" \> /etc/sysconfig/slurmd


# Add Network Time Protocol (NTP) support
psh cnode02 yum -y  install chrony
psh cnode02 systemctl enable chronyd
# Identify master host as local NTP server
##cd ${package_dir}
##echo "server ${sms_ip}" > ./chrony.conf
##pscp ./chrony.conf cnode02:/etc/
psh cnode02  echo "server ${sms_ip}" \>\> /etc/chrony.conf

##################### add autofs #################################
psh cnode02 yum -y install autofs
psh cnode02 systemctl enable autofs

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


## scp file , cnode02 is node group ##
pscp ./auto.* cnode02:/etc/
##################### add autofs  end #################################


# Update memlock settings within cnode02 image, this is not wort with psh 
psh cnode02 perl -pi -e "'s/# End of file/\* soft memlock unlimited\n$&/s'" /etc/security/limits.conf
psh cnode02 perl -pi -e "'s/# End of file/\* hard memlock unlimited\n$&/s'" /etc/security/limits.conf
#####

# Enable ssh control via resource manager
psh cnode02  echo "account required pam_slurm.so" \>\> /etc/pam.d/sshd

###### reboot the cnode02 node ####
######        the cnode02 node ####
######            cnode02 node ####
######                    node ####
######                         ####

## xdcp cnode02 /etc/slurm/slurm.conf /etc/slurm/slurm.conf
xdcp cnode02 /etc/munge/munge.key /etc/munge/munge.key

#
# Create a sync file for pushing user credentials to the nodes
echo "MERGE:" > syncusers
echo "/etc/passwd -> /etc/passwd" >> syncusers
echo "/etc/group -> /etc/group" >> syncusers
echo "/etc/shadow -> /etc/shadow" >> syncusers
# Use xCAT to distribute credentials to nodes
xdcp cnode02 -F syncusers