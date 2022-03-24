#!/bin/sh

## moldify it !!!!!!!!!!
export base_dir=/mnt/usb1
export package_dir=${base_dir}/OHPC
export iso_path=${base_dir}/OS
# export package_dir=/root/package
# export iso_path=${package_dir}

## moldify it !!!!!!!!!!
export sms_eth_internal=ens34
export eth_provision=${sms_eth_internal}

export sms_name=cjhpc
export sms_ip=10.0.0.1

export internal_netmask=255.255.255.0
export internal_netmask_l=24
export ntp_server=10.0.0.1

export c_ip_pre=10.0.0.1

export sms_ipoib=10.0.1.1
export ipoib_netmask=255.255.255.0
export c_ipoib_pre=10.0.1.1

export compute_prefix=cnode
##export kargs=net.ifnames=1




##export CHROOT=/opt/ohpc/admin/images/rocky8.5

### this can be set as a real domain name, such as buildhpc.org###
## so the sms /etc/hosts is as #
#10.0.0.2 cjhpc cjhpc.buildhpc
#10.0.0.201 cnode01 cnode01.build.hpc
###
export domain_name=local


