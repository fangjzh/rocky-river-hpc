#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置ohpc base 和 xcat - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log
######install ohpc and xcat #########
yum -y -q install ohpc-base xCAT.x86_64 >${0##*/}.log 2>&1

# enable xCAT tools for use in current shell
. /etc/profile.d/xcat.sh

if [ $? != 0 ]; then
    echo xcat install or initiation error!
    exit
fi

# Register internal provisioning interface with xCAT for DHCP
chdef -t site dhcpinterfaces="xcatmn|${sms_eth_internal}"
####
chdef -t site domain=${domain_name}
###
chdef -t site dhcpinterfaces="${sms_eth_internal}"

chtab key=system passwd.username=root passwd.password=$(openssl rand -base64 12)

##copycds -p /installl/centos8.4/x86_64 -n=centos8.4 ${iso_path}/Rocky-8.4-x86_64-dvd1.iso
copycds ${iso_path}/${iso_name}
## also can copy from dvd device
## copycds /dev/cdrom

# lsdef -t osimage   ### get the image names used by genimage

#########  add postbootscripts ####
if [ ! -e ./sample_files/mypostboot.bash ]; then
    echo "mypostboot.bash is not exist!!!"
    exit
fi
/bin/cp ./sample_files/mypostboot.bash /install/postscripts/mypostboot
sed -i 's/10.0.0.1/'${sms_ip}'/' /install/postscripts/mypostboot
sed -i 's/sms_name=cjhpc/sms_name='${sms_name}'/' /install/postscripts/mypostboot
sed -i 's/domain_name=local/domain_name='${domain_name}'/' /install/postscripts/mypostboot
chmod +x /install/postscripts/mypostboot

echo "-->执行 $0 : 安装设置ohpc base 和 xcat 完毕 + = + = + = + = + ="
echo "$0 执行完成！" >>${0##*/}.log
