#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

########## add hack sulotion of rocky os support #######
# cd ${package_dir}
perl -pi -e 'print "    \"1636882174.934804\" => \"rocky8.5\",      #x86_64\n" if $. == 17' /opt/xcat/lib/perl/xCAT/data/discinfo.pm 

systemctl restart xcatd
# cd ~
#########################################################

chtab key=system passwd.username=root passwd.password=`openssl rand -base64 12`

##copycds -p /installl/centos8.4/x86_64 -n=centos8.4 ${iso_path}/Rocky-8.4-x86_64-dvd1.iso 
copycds  ${iso_path}/Rocky-8.5-x86_64-dvd1.iso
## also can copy from dvd device 
## copycds /dev/cdrom

lsdef -t osimage   ### get the image names used by genimage

chdef -t site dhcpinterfaces="${sms_eth_internal}"

## don't use this two script, it may cause compute node would not get ip addr affter install
##chdef -t network 10_0_0_0-255_255_255_0 dynamicrange="10.0.0.201-10.0.0.250"
##chdef -t network 10_0_0_0-255_255_255_0 dynamicrange=""

#####
## echo "if selinux is not disabled and reboot the system, do it and reboot!!! now!"