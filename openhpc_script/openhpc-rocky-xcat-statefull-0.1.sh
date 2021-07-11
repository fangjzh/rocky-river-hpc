#!/bin/bash
### 2021/07/11:  

### todo list #####
### devide this script in to functions and sub script
### make addnode script
### make adduser script
### config slurm in detail: partition & user access & accounting


export sms_name=cjhpc
export sms_ip=10.0.0.3
export sms_eth_internal=enp0s8
export eth_provision=enp0s8
export internal_netmask=255.255.255.0
export internal_netmask_l=24
export ntp_server=10.0.0.2

export c_ip_pre=10.0.0.2

export sms_ipoib=10.0.1.1
export ipoib_netmask=255.255.255.0
export c_ipoib_pre=10.0.1.1

export compute_prefix=cnode
##export kargs=net.ifnames=1

export iso_path=/root/package

##export CHROOT=/opt/ohpc/admin/images/rocky8.4

### this can be set as a real domain name, such as buildhpc.org###
## so the sms /etc/hosts is as #
#10.0.0.2 cjhpc cjhpc.buildhpc
#10.0.0.201 cnode01 cnode01.build.hpc
###
export domain_name=local



######set package dir####
pacakge_source_dir=/mnt/media/xxx

##copy to local hardisk
package_dir=/root/package
mkdir ${package_dir}
cp  ${pacakge_source_dir}/Rocky-8.4-x86_64-dvd1.iso   ${package_dir}/
cp  ${pacakge_source_dir}/epel.tar  ${package_dir}/
cp  ${pacakge_source_dir}/RockyOs.tgz  ${package_dir}/

cp  ${pacakge_source_dir}/OpenHPC-2.3.CentOS_8.x86_64.tar  ${package_dir}/
mkdir -p ${package_dir}/xcat
cp  ${pacakge_source_dir}/xcat/xcat-dep-2.16.2-linux.tar.bz2 ${package_dir}/xcat
cp  ${pacakge_source_dir}/xcat/xcat-core-2.16.2-linux.tar.bz2 ${package_dir}/xcat

cp  ${pacakge_source_dir}/Rocky-local.repo ${package_dir}/
cp  ${pacakge_source_dir}/env_tmp.sh ${package_dir}/
cp  ${pacakge_source_dir}/job.sh ${package_dir}/

cp  ${pacakge_source_dir}/l_BaseKit_p_2021.3.0.3219_offline.sh  ${package_dir}/
cp  ${pacakge_source_dir}/l_HPCKit_p_2021.3.0.3230_offline.sh   ${package_dir}/

cp ${pacakge_source_dir}/lammps   ${package_dir}/

cd ${package_dir}
###

###make local repo####
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

mkdir -p /opt/repo/rocky
mkdir -p /root/iso_mnt
mount -o loop ${package_dir}/Rocky-8.4-x86_64-dvd1.iso   /root/iso_mnt
cp -r /root/iso_mnt/*  /opt/repo/rocky

# for virmachine mount cdrom device
# mkdir /mnt/cdrom
# mount -t auto /dev/cdrom /mnt/cdrom
# cp -r /mnt/cdrom/*  /opt/repo/rocky

##cp -r ${package_dir}/Rocky-package/* /opt/repo/rocky

tar -xvf ${package_dir}/epel.tar -C /opt/repo/rocky
tar -xvzf ${package_dir}/RockyOs.tgz -C /opt/repo/rocky
mv /opt/repo/rocky/RockyOs/* /opt/repo/rocky
rm -rf /opt/repo/rocky/RockyOs

/bin/cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/

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


### create repo file for compute node ###
##package_dir=/root/package
cat ${package_dir}/Rocky-local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' > /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/OpenHPC.local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-core.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-dep.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo

#########change server name#########
echo ${sms_name} > /etc/hostname
echo "${sms_ip}  ${sms_name}  ${sms_name}.${domain_name}" >>/etc/hosts
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
### need reboot ##


######install ohpc #########
yum -y install ohpc-base

######install xcat #####
yum -y install xCAT
# enable xCAT tools for use in current shell
. /etc/profile.d/xcat.sh

# Register internal provisioning interface with xCAT for DHCP
chdef -t site dhcpinterfaces="xcatmn|${sms_eth_internal}"
####
chdef -t site domain=${domain_name}

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


cat >/etc/httpd/conf.d/repo.conf <<'EOF'
AliasMatch ^/opt/repo/(.*)$ "/opt/repo/$1"
<Directory "/opt/repo">
    Options Indexes FollowSymLinks Includes MultiViews
    AllowOverride None
    Require all granted
</Directory>
EOF

systemctl restart httpd



#################  Build initial BOS image  ########################
############### rocky cannot be recognised by copycds ##############

###get the disk info from the dvd1.iso##
#### mkdir -p /root/iso_tmp
#### mount -o loop ${package_dir}/Rocky-8.4-x86_64-dvd1.iso   /root/iso_tmp
#### a=$(cat /root/iso_tmp/.discinfo | awk 'NR==1{a=$0}NR==2{b=$0}NR==3{c=$0}END{print "\""a"\"  => " "\"rocky8.4\", #"  c}')
#### sed -i '16a'"${a}"'' /opt/xcat/lib/perl/xCAT/data/discinfo.pm
#### umount /root/iso_tmp
#### ###modify  /opt/xcat/lib/perl/xCAT/data/discinfo.pm###
#### systemctl restart xcatd
#### 
#### cp -r /opt/xcat/share/xcat/install/centos /opt/xcat/share/xcat/install/rocky
#### cd /opt/xcat/share/xcat/install/rocky
#### cp  compute.centos8.tmpl    compute.rocky8.tmpl 
#### cp  compute.centos8.pkglist compute.rocky8.pkglist
#### 
#### cp -r /opt/xcat/share/xcat/netboot/centos /opt/xcat/share/xcat/netboot/rocky
#### cd /opt/xcat/share/xcat/netboot/rocky
#### cp compute.centos8.x86_64.exlist compute.rocky8.x86_64.exlist
#### cp compute.centos8.x86_64.pkglist compute.rocky8.x86_64.pkglist

########## add hack sulotion of rocky os support #######
cd ${package_dir}
tar -xvzf backup_xcat_hack.tgz
cd backup_xcat_hack
cp -r install /opt/xcat/share/xcat/install/rocky 
cp -r netboot /opt/xcat/share/xcat/netboot/rocky 
/bin/cp ./discinfo.pm /opt/xcat/lib/perl/xCAT/data/discinfo.pm 
/bin/cp ./imgcapture.pm /opt/xcat/lib/perl/xCAT_plugin/imgcapture.pm 
/bin/cp ./imgport.pm /opt/xcat/lib/perl/xCAT_plugin/imgport.pm 
/bin/cp ./anaconda.pm /opt/xcat/lib/perl/xCAT_plugin/anaconda.pm 
/bin/cp ./geninitrd.pm /opt/xcat/lib/perl/xCAT_plugin/geninitrd.pm 
/bin/cp ./route.pm /opt/xcat/lib/perl/xCAT_plugin/route.pm 
/bin/cp ./Postage.pm /opt/xcat/lib/perl/xCAT/Postage.pm 
/bin/cp ./Utils.pm /opt/xcat/lib/perl/xCAT/Utils.pm 
/bin/cp ./ProfiledNodeUtils.pm /opt/xcat/lib/perl/xCAT/ProfiledNodeUtils.pm 
/bin/cp ./SvrUtils.pm /opt/xcat/lib/perl/xCAT/SvrUtils.pm 
/bin/cp ./Template.pm /opt/xcat/lib/perl/xCAT/Template.pm 
/bin/cp ./Schema.pm /opt/xcat/lib/perl/xCAT/Schema.pm 
systemctl restart xcatd
cd ~
#########################################################

#### Install ClusterShell
yum -y install clustershell
# Setup node definitions
cd /etc/clustershell/groups.d
cat local.cfg > local.cfg.orig
echo "adm: ${sms_name}" > local.cfg
echo "compute: ${compute_prefix}0[1-3]" >> local.cfg   ####need to be modified
echo "all: @adm,@compute" >> local.cfg
cd ~
######

# Update memlock settings on master
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf

# Disable /tftpboot and /install export entries
perl -pi -e "s|/tftpboot|#/tftpboot|" /etc/exports
perl -pi -e "s|/install|#/install|" /etc/exports
### note: fsid should be uniq, if add dir###
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports
echo "/opt/repo *(ro,no_subtree_check,fsid=12)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
systemctl enable nfs-server











#########################################################
##### remember three command : mkdef rmdef chdef lsdef ########
#########################################################

########### Definecomputeimage for provisioning ###########
####                                                #######
####                                                #######
##copycds -p /installl/centos8.4/x86_64 -n=centos8.4 ${iso_path}/Rocky-8.4-x86_64-dvd1.iso 
copycds  ${iso_path}/Rocky-8.4-x86_64-dvd1.iso

## also can copy from dvd device 
## copycds /dev/cdrom

### copycds will match .discinfo in the iso with /opt/xcat/lib/perl/xCAT/data/discinfo.pm
### then math the file name in /opt/xcat/share/xcat/netboot and /opt/xcat/share/xcat/install
### then generate the osimage rules

lsdef -t osimage   ### get the image names used by genimage
#rmimage centos8.4-x86_64-netboot-compute  --xcatdef  ###　deleted the definitions
#rmdef -t osimage centos8.4-x86_64-install-compute
#rmdef -t osimage centos8.4-x86_64-statelite-compute

image_choose=rocky8.4-x86_64-install-compute

###echo "autofs" >> /opt/xcat/share/xcat/install/rocky/compute.rocky8.pkglist


chtab key=system passwd.username=root passwd.password=`openssl rand -base64 12`


###add compute node###
num_computes=2
c_name[0]=cnode01
c_name[1]=cnode02
c_ip[0]=${c_ip_pre}01
c_ip[1]=${c_ip_pre}02
c_mac[0]=08:00:27:70:4C:A9
c_mac[1]=08:00:27:16:96:29


for ((i=0; i<$num_computes; i++)) ; do
  mkdef -t node ${c_name[$i]} groups=compute,all ip=${c_ip[$i]} mac=${c_mac[$i]} netboot=xnba \
  arch=x86_64 
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


####check xcat server########
## if something is not set ##
##xcatprobe xcatmn 
###xcatprobe xcatmn -i ${sms_eth_internal}


## boot compute-node ###
### Waiting for the installation process ####


##############################################################################
#########################################################################
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


###  the 2nd way to sync users ####
##  # Define path for xCAT synclist file
##  mkdir -p /install/custom/install
##  image_choose=rocky8.4-x86_64-install-compute
##  chdef -t osimage -o ${image_choose} synclists="/install/custom/install/compute.synclist"
##  # Add desired credential files to synclist
##  echo "/etc/passwd -> /etc/passwd" > /install/custom/install/compute.synclist
##  echo "/etc/group -> /etc/group" >> /install/custom/install/compute.synclist
##  echo "/etc/shadow -> /etc/shadow" >> /install/custom/install/compute.synclist
##  ##
##  echo "/etc/munge/munge.key -> /etc/munge/munge.key" >>/install/custom/install/compute.synclist

## when unsers are added , execute the command 
## updatenode cnode02 -F
###  updatenode compute -F

### The “updatenode compute -F” command can be used to distribute changes made 
### to any defined synchro-nization files on the SMS host.  

##############################################################################
#########################################################################
##############################################################################






#######################################################################
#######################################################################

###install develop tools##
yum -y install ohpc-autotools
yum -y install EasyBuild-ohpc
yum -y install gnu9-compilers-ohpc
yum -y install mpich-ucx-gnu9-ohpc
yum -y install openmpi4-gnu9-ohpc mpich-ofi-gnu9-ohpc
####
yum -y install lmod-defaults-gnu9-openmpi4-ohpc

#####install intel one api########
###extract and install#
cd ${package_dir}
sh l_BaseKit_p_2021.3.0.3219_offline.sh -x 
cd l_BaseKit_p_2021.3.0.3219_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel  --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

cd ${package_dir}
sh l_HPCKit_p_2021.3.0.3230_offline.sh -x
cd l_HPCKit_p_2021.3.0.3230_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.ifort-compiler:intel.oneapi.lin.dpcpp-cpp-compiler-pro:intel.oneapi.lin.mpi.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

#./install.sh --list-products
#./install.sh --list-components --product-id intel.oneapi.lin.basekit.product --product-ver 2021.3.0-3219
#./install.sh --list-components --product-id intel.oneapi.lin.hpckit.product --product-ver 2021.3.0-3230

#the pacakge is installed as big as 22G, uninstaller is in /opt/intel##
# install tmpfiles is in /opt/intel/oneapi/installer, can repair install #

## how to make module###
/opt/ohpc/pub/apps/intel/modulefiles-setup.sh

echo 'export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' >> /etc/profile.d/lmod.sh

## this command is ok 
pdsh -w ${compute_prefix}0[1-2]  echo 'export MODULEPATH=\${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' \>\> /etc/profile.d/lmod.sh
## also can add in /etc/profile.d/lmod.sh
##export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/compiler/latest/modulefiles:/opt/ohpc/pub/apps/intel/mkl/latest/modulefiles:/opt/ohpc/pub/apps/intel/mpi/latest/modulefiles:/opt/ohpc/pub/apps/intel/tbb/latest/modulefiles



#######################################################################
#######################################################################

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
pdsh -w cnode02 systemctl start munge
pdsh -w cnode02 systemctl start slurmd



