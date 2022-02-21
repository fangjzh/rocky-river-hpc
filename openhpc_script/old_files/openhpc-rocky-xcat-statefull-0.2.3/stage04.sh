#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh
image_choose=rocky8.4-x86_64-install-compute

###add compute node###
num_computes=2

c_name[0]=cnode01
c_ip[0]=${c_ip_pre}01
c_mac[0]=00:50:56:3D:7D:05
Sockets[0]=1 
CoresPerSocket[0]=1 
ThreadsPerCore[0]=1

c_name[1]=cnode02
c_ip[1]=${c_ip_pre}02
c_mac[1]=00:50:56:26:2E:D3
Sockets[1]=1 
CoresPerSocket[1]=1 
ThreadsPerCore[1]=1

for ((i=0; i<$num_computes; i++)) ; do
  mkdef -t node ${c_name[$i]} groups=compute,all ip=${c_ip[$i]} mac=${c_mac[$i]} netboot=xnba \
  arch=x86_64 
  echo "NodeName=${c_name[$i]}  Sockets=${Sockets[$i]} CoresPerSocket=${CoresPerSocket[$i]} ThreadsPerCore=${ThreadsPerCore[$i]} State=UNKNOWN" >> /etc/slurm/slurm.conf
done

# Complete network service configurations
makehosts
makenetworks

chdef -t site dhcpinterfaces="${sms_eth_internal}"
makedhcp -n

### perl -pi -e 's/'"${sms_name}"'/'"${sms_name}"' '"${sms_name}"'.'"${domain_name}"'/' /etc/hosts
makedns -n

# Associate desired provisioning image for computes
nodeset compute osimage=${image_choose}
## if u need to reinstall the node, use this command ##

### add postbootscripts to compute node ####
chdef compute -p postbootscripts=mypostboot