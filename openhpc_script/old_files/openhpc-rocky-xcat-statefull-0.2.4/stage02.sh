#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

########## add hack sulotion of rocky os support #######
cd ${package_dir}
tar -xzf backup_xcat_hack.tgz
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

chtab key=system passwd.username=root passwd.password=`openssl rand -base64 12`

##copycds -p /installl/centos8.4/x86_64 -n=centos8.4 ${iso_path}/Rocky-8.4-x86_64-dvd1.iso 
copycds  ${iso_path}/Rocky-8.4-x86_64-dvd1.iso
## also can copy from dvd device 
## copycds /dev/cdrom

lsdef -t osimage   ### get the image names used by genimage

chdef -t site dhcpinterfaces="${sms_eth_internal}"

## don't use this two script, it may cause compute node would not get ip addr affter install
##chdef -t network 10_0_0_0-255_255_255_0 dynamicrange="10.0.0.201-10.0.0.250"
##chdef -t network 10_0_0_0-255_255_255_0 dynamicrange=""

#####
## echo "if selinux is not disabled and reboot the system, do it and reboot!!! now!"