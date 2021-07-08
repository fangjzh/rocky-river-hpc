sms_name=cjhpc
sms_ip=10.0.0.1
sms_eth_internal=enp0s8
eth_provision=enp0s8
internal_netmask=255.255.255.0
internal_netmask_l=24
ntp_server=10.0.0.1

c_ip_pre=10.0.0.1

sms_ipoib=10.0.1.1
ipoib_netmask=255.255.255.0
c_ipoib_pre=10.0.1.1

compute_prefix=cnode
kargs=net.ifnames=1

export CHROOT=/opt/ohpc/admin/images/rocky8.4

######set package dir####
package_dir=/root/package
mkdir ${package_dir}


###make local repo####
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

mkdir -p /opt/repo/rocky
mkdir -p /root/iso_mnt
mount -o loop ${package_dir}/Rocky-8.4-x86_64-dvd1.iso   /root/iso_mnt
cp -r /root/iso_mnt/*  /opt/repo/rocky
cp -r ${package_dir}/Rocky-package/* /opt/repo/rocky
cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/

mkdir -p /opt/repo/openhpc
tar -xvf ${package_dir}/OpenHPC-2.3.CentOS_8.x86_64.tar -C /opt/repo/openhpc
/opt/repo/openhpc/make_repo.sh

mkdir -p /opt/repo/xcat
tar -xvjf ${package_dir}/xcat/xcat-dep-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
tar -xvjf ${package_dir}/xcat/xcat-core-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
/opt/repo/xcat/xcat-dep/rh8/x86_64/mklocalrepo.sh
/opt/repo/xcat/xcat-core/mklocalrepo.sh

yum clean all
yum makecache
#######################


#########change server name#########
echo ${sms_name} > /etc/hostname    
echo "${sms_ip} ${sms_name}" >>/etc/hosts
nmcli g hostname ${sms_name}


#########set internal interface####
nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli conn up ${sms_eth_internal}

########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux


######install ohpc #########
yum -y install ohpc-base

######set ntp server########
systemctl enable chronyd.service       
echo "server ${sms_name}" >> /etc/chrony.conf
echo "allow all" >> /etc/chrony.conf   
systemctl restart chronyd 

#### install slurm ######
yum -y install ohpc-slurm-server
cp /etc/slurm/slurm.conf.ohpc /etc/slurm/slurm.conf
perl -pi -e "s/ControlMachine=\S+/ControlMachine=${sms_name}/" /etc/slurm/slurm.conf
##
perl -pi -e "s/JobCompType=jobcomp\/none/#JobCompType=jobcomp\/none/" /etc/slurm/slurm.conf
### slurm.conf need to be modified.


######install warewulf#####
yum -y install ohpc-warewulf
perl -pi -e "s/device = eth1/device = ${eth_provision}/" /etc/warewulf/provision.conf

####start services#####
systemctl enable httpd.service
systemctl restart httpd
systemctl enable dhcpd.service
systemctl enable tftp.socket
systemctl start tftp.socket

#################

####################################
######## build computenode image
###########################################

##### enable local source ####
export YUM_MIRROR=/opt/repo/rocky/BaseOS,/opt/repo/rocky/AppStream,/opt/repo/rocky/extras,/opt/repo/rocky/PowerTools,/opt/repo/rocky/epel

### make imge dir####
mkdir -p /opt/ohpc/admin/images/rocky8.4
export CHROOT=/opt/ohpc/admin/images/rocky8.4
### build initial image###
wwmkchroot -v rocky-8 $CHROOT

###copy repo conf into image###
perl -pi -e "s/enabled=1/enabled=0/" $CHROOT/etc/yum.repos.d/opt_repo_rocky*.repo
cp /etc/yum.repos.d/Rocky-local.repo /opt/ohpc/admin/images/rocky8.4/etc/yum.repos.d/Rocky-local.repo
cp -p /etc/yum.repos.d/OpenHPC*.repo $CHROOT/etc/yum.repos.d
###install software into image###
yum -y --installroot=$CHROOT install ohpc-base-compute.x86_64
cp -p /etc/resolv.conf $CHROOT/etc/resolv.conf

# copy credential files into $CHROOT to ensure consistent uid/gids for slurm/munge at
# install. Note that these will be synchronized with future updates via the provisioning system.
/bin/cp /etc/passwd /etc/group $CHROOT/etc

# Add Slurm client support meta-package and enable munge
yum -y --installroot=$CHROOT install ohpc-slurm-client
chroot $CHROOT systemctl enable munge  
chroot $CHROOT systemctl enable slurmd

# Register Slurm server with computes (using "configless" option)
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" > $CHROOT/etc/sysconfig/slurmd

# Add Network Time Protocol (NTP) support
yum -y --installroot=$CHROOT install chrony

# Identify master host as local NTP server
echo "server ${sms_ip}" >> $CHROOT/etc/chrony.conf

# Add kernel drivers (matching kernel version on SMS node)
yum -y --installroot=$CHROOT install kernel-`uname -r`

# Include modules user environment
yum -y --installroot=$CHROOT install lmod-ohpc
 
####### initialize warewulf database and ssh_keys###
wwinit database 
wwinit ssh_keys

###### setup nfs #####
mkdir ${CHROOT}/opt/repo
echo "${sms_ip}:/home /home nfs nfsvers=3,nodev,nosuid 0 0" >> $CHROOT/etc/fstab
echo "${sms_ip}:/opt/ohpc/pub /opt/ohpc/pub nfs nfsvers=3,nodev 0 0" >> $CHROOT/etc/fstab
echo "${sms_ip}:/opt/repo /opt/repo nfs nfsvers=3,nodev 0 0" >> $CHROOT/etc/fstab

### note to fsid, if add dir###
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports
echo "/opt/repo *(ro,no_subtree_check,fsid=12)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
systemctl enable nfs-server


#### Install ClusterShell
yum -y install clustershell
# Setup node definitions
cd /etc/clustershell/groups.d
mv local.cfg local.cfg.orig
echo "adm: ${sms_name}" > local.cfg
echo "compute: ${compute_prefix}0[1-3]" >> local.cfg   ####need to be modified
echo "all: @adm,@compute" >> local.cfg
cd ~
######

###import files ###
wwsh file import /etc/passwd
wwsh file import /etc/group
wwsh file import /etc/shadow
wwsh file import /etc/munge/munge.key

####make boot image###
wwbootstrap `uname -r`

###make vnfs#####
wwvnfs --chroot $CHROOT


###add compute node###
tmp_mac=08:00:27:70:4C:A9
echo "GATEWAYDEV=eth0" > /tmp/network.$$
wwsh -y file import /tmp/network.$$ --name network
wwsh -y file set network --path /etc/sysconfig/network --mode=0644 --uid=0
wwsh -y node new ${compute_prefix}01 --ipaddr=${c_ip_pre}01 --hwaddr=${tmp_mac} -D eth0
wwsh -y provision set ${compute_prefix}0* --vnfs=rocky8.4 --bootstrap=`uname -r` \
--files=dynamic_hosts,passwd,group,shadow,munge.key,network
##export kargs="${kargs} net.ifnames=0,biosdevname=0"
wwsh -y provision set --postnetdown=1 "${compute_prefix}0[1-5]"
##
systemctl restart dhcpd
wwsh pxe update

########## make the node statefull########
##install grub and efi##
export CHROOT=/opt/ohpc/admin/images/rocky8.4
yum -y --installroot=${CHROOT} install kernel grub2
/bin/cp /etc/os-release ${CHROOT}/etc/os-release
###
wwvnfs --chroot $CHROOT

cp  /etc/warewulf/filesystem/examples/gpt_example.cmds   /etc/warewulf/filesystem/gpt.cmds
wwsh -y provision set --filesystem=gpt cnode01
wwsh -y provision set --bootloader=sda cnode01

### if uefi is needed ##
##yum -y --installroot=${CHROOT} install grub2-efi-x64-modules.noarch grub2-efi-x64-cdboot.x86_64
##wwvnfs --chroot $CHROOT
##cp  /etc/warewulf/filesystem/examples/efi_example.cmds /etc/warewulf/filesystem/efi.cmds
##wwsh -y provision set --filesystem=efi cnode01
##wwsh -y provision set --bootloader=sda cnode01


###if the computenode is installed then###
wwsh -y provision set --bootlocal=normal cnode01


### if uefi is needed ##
##yum -y --installroot=${CHROOT} install grub2-efi-x64-modules.noarch grub2-efi-x64-cdboot.x86_64
##wwvnfs --chroot $CHROOT
##cp  /etc/warewulf/filesystem/examples/efi_example.cmds /etc/warewulf/filesystem/efi.cmds
##wwsh -y provision set --filesystem=efi cnode01
##wwsh -y provision set --bootloader=UNDEF cnode01


###install develop tools##
yum -y install ohpc-autotools
yum -y install EasyBuild-ohpc
yum -y install gnu9-compilers-ohpc
yum -y install mpich-ucx-gnu9-ohpc
yum -y install openmpi4-gnu9-ohpc mpich-ofi-gnu9-ohpc
####
yum -y install lmod-defaults-gnu9-openmpi4-ohpc

######
## moldify the /etc/slurm/slurm.conf
## change node name, cpu number, slots et.al.
################

###start slurm###
systemctl enable munge
systemctl enable slurmctld
systemctl start munge
systemctl start slurmctld

##pdsh -w cnode0[1-2] systemctl enable munge
##pdsh -w cnode0[1-2] systemctl enable slurmd
pdsh -w cnode01 systemctl start munge
pdsh -w cnode01 systemctl start slurmd

#####install intel one api########
###extract and install#
./l_BaseKit_p_2021.3.0.3219_offline.sh -x 
cd l_BaseKit_p_2021.3.0.3219_offline
./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

./l_HPCKit_p_2021.3.0.3230_offline.sh -x
cd l_HPCKit_p_2021.3.0.3230_offline
./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

#the pacakge is installed as big as 22G, uninstaller is in /opt/intel##
## how to make module###
/opt/ohpc/pub/apps/intel/modulefiles-setup.sh

##export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles
## also can add in /etc/profile.d/lmod.sh
export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/compiler/latest/modulefiles:/opt/ohpc/pub/apps/intel/mkl/latest/modulefiles:/opt/ohpc/pub/apps/intel/mpi/latest/modulefiles:/opt/ohpc/pub/apps/intel/tbb/latest/modulefiles

