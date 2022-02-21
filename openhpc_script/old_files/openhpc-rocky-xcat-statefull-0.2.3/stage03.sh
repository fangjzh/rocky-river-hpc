#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

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

## image_choose=rocky8.4-x86_64-install-compute

###echo "autofs" >> /opt/xcat/share/xcat/install/rocky/compute.rocky8.pkglist





##ln -s /opt/repo/openhpc/CentOS_8/ /install/rocky8.4/x86_64/openhpc
##ln -s /opt/repo/rocky/extras/ /install/rocky8.4/x86_64/extras
##ln -s /opt/repo/rocky/PowerTools/ /install/rocky8.4/x86_64/PowerTools
##ln -s /opt/repo/rocky/epel/ /install/rocky8.4/x86_64/epel
