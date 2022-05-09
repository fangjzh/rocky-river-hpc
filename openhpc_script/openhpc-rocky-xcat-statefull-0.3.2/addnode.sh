#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

################################################################
virsh domiflist cnode03

source env.sh
c_name[0]=cnode03
c_ip[0]=${c_ip_pre}03
c_mac[0]=52:54:00:fb:69:a1
Sockets[0]=1 
CoresPerSocket[0]=2 
ThreadsPerCore[0]=1

i=0
mkdef -t node ${c_name[$i]} groups=compute,all ip=${c_ip[$i]} mac=${c_mac[$i]} netboot=xnba \
arch=x86_64 
echo "NodeName=${c_name[$i]}  Sockets=${Sockets[$i]} CoresPerSocket=${CoresPerSocket[$i]} \
ThreadsPerCore=${ThreadsPerCore[$i]} State=UNKNOWN" >> /etc/slurm/slurm.conf

makehosts
makenetworks
makedhcp -n
### perl -pi -e 's/'"${sms_name}"'/'"${sms_name}"' '"${sms_name}"'.'"${domain_name}"'/' /etc/hosts
makedns -n

# Associate desired provisioning image for computes
image_choose=rocky8.5-x86_64-install-compute
nodeset cnode03 osimage=${image_choose}
chdef cnode03 -p postbootscripts=mypostboot

######## add ipmi support ######
nodech cnode03 nodehm.power=ipmi nodehm.mgt=ipmi
nodech cnode03 ipmi.bmc=10.0.0.2 ipmi.port=6203  ipmi.username=admin ipmi.password=password
lsdef -t node cnode03

rpower cnode03 stat
rpower cnode03 on