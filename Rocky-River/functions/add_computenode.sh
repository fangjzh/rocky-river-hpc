#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

#####################################################
#####################################################
#####################################################
################   需要修改   #######################
#####################################################
#####################################################
#####################################################

. /etc/profile.d/xcat.sh

lsdef -t osimage | grep compute


###add compute node###
num_computes=2

c_name[0]=cnode01
c_ip[0]=${c_ip_pre}01
c_mac[0]=00:50:56:36:D2:9D
Sockets[0]=1 
CoresPerSocket[0]=2 
ThreadsPerCore[0]=1

c_name[1]=cnode02
c_ip[1]=${c_ip_pre}02
c_mac[1]=08:00:27:AC:6A:9C
Sockets[1]=1 
CoresPerSocket[1]=2 
ThreadsPerCore[1]=1

for ((i=0; i<$num_computes; i++)) ; do
  mkdef -t node ${c_name[$i]} groups=compute,all ip=${c_ip[$i]} mac=${c_mac[$i]} netboot=xnba \
  arch=x86_64 
  echo "NodeName=${c_name[$i]}  Sockets=${Sockets[$i]} CoresPerSocket=${CoresPerSocket[$i]} \
  ThreadsPerCore=${ThreadsPerCore[$i]} State=UNKNOWN" >> /etc/slurm/slurm.conf
done

# Complete network service configurations
makehosts
makenetworks

makedhcp -n

### perl -pi -e 's/'"${sms_name}"'/'"${sms_name}"' '"${sms_name}"'.'"${domain_name}"'/' /etc/hosts
makedns -n

# Associate desired provisioning image for computes
image_choose=rocky8.5-x86_64-install-compute
nodeset compute osimage=${image_choose}
## if u need to reinstall the node, use this command ##

### add postbootscripts to compute node ####
chdef compute -p postbootscripts=mypostboot

######## add ipmi support ######
 # nodech compute nodehm.power=ipmi nodehm.mgt=ipmi
 # nodech cnode01 ipmi.bmc=10.0.0.2 ipmi.username=admin ipmi.password=password
 # nodech cnode02 ipmi.bmc=10.0.0.3 ipmi.port=623  ipmi.username=admin ipmi.password=password
 # lsdef -t node cnode02

## xdcp ${nodename} /etc/slurm/slurm.conf /etc/slurm/slurm.conf
xdcp compute /etc/munge/munge.key /etc/munge/munge.key


#######################################################################
#######################################################################


## 计算节点添加Intel 编译器module
## this command is ok 
pdsh -w ${compute_prefix}0[1-2]  echo 'export MODULEPATH=\${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' \>\> /etc/profile.d/lmod.sh

## 强制时间同步
pdsh -w ${compute_prefix}0[1-2]  chronyc -a makestep

#######################################################################
#######################################################################

######
## moldify the /etc/slurm/slurm.conf
## change node name, cpu number, slots et.al.
################
sed -i '/^PartitionName=normal/d'  /etc/slurm/slurm.conf
nodenum=$(cat /etc/hosts | grep ${compute_prefix}0 |wc -l)
echo "PartitionName=normal Nodes=${compute_prefix}0[1-${nodenum}] Default=YES MaxTime=168:00:00 State=UP Oversubscribe=YES" >> /etc/slurm/slurm.conf


systemctl restart munge
systemctl restart slurmctld


pdsh -w cnode0[1-2] systemctl restart munge
pdsh -w cnode0[1-2] systemctl restart slurmd

scontrol update NodeName=cnode0p[1-3] State=RESUME

