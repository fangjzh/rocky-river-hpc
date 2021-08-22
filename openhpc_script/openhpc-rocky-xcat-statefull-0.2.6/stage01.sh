#!/bin/sh
source ./env.sh

### 修复网卡名称 ###
if [ ! -e /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal} ] ; then
  echo "/etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal} is not exist!!!"
  exit
else
perl -pi -e "s/NAME=.+/NAME=\"${sms_eth_internal}\"/" /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal}
perl -pi -e "s/DEVICE=.+/DEVICE=${sms_eth_internal}/" /etc/sysconfig/network-scripts/ifcfg-${sms_eth_internal}
nmcli c reload
fi

#########set internal interface####
nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli conn up ${sms_eth_internal}

if [ $? != 0 ]; then
echo "network error!"
exit
fi

###设置时区###
# timedatectl list-timezones
timedatectl set-timezone Asia/Shanghai
# timedatectl set-local-rtc 0
# timedatectl set-time "2021-08-21 18:29:30"
#  hwclock -w

#########change server name#########
echo ${sms_name} > /etc/hostname
echo "${sms_ip}  ${sms_name}  ${sms_name}.${domain_name}" >>/etc/hosts
nmcli g hostname ${sms_name}


########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##


######install ohpc and xcat #########
yum -y -q install ohpc-base  xCAT.x86_64 


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


#########  add postbootscripts ####
if [ ! -e ./mypostboot.bash ] ; then
  echo "./mypostboot.bash is not exist!!!"
  exit
fi
/bin/cp ./mypostboot.bash /install/postscripts/mypostboot
sed -i 's/10.0.0.1/'${sms_ip}'/' /install/postscripts/mypostboot
sed -i 's/sms_name=cjhpc/sms_name='${sms_name}'/' /install/postscripts/mypostboot
sed -i 's/domain_name=local/domain_name='${domain_name}'/' /install/postscripts/mypostboot
chmod +x /install/postscripts/mypostboot


###disable ipv6####
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

######set ntp server########
yum -y -q install chrony
systemctl enable chronyd.service
echo "server ntp1.aliyun.com iburst " >> /etc/chrony.conf 
echo "server ntp.ntsc.ac.cn iburst" >> /etc/chrony.conf
echo "allow ${sms_ip}/${internal_netmask_l}" >> /etc/chrony.conf   
perl -pi -e "s/#local\ stratum/local\ stratum/" /etc/chrony.conf   
systemctl restart chronyd 

####

#### install slurm ######
yum -y -q install mailx munge ohpc-slurm-server  
/bin/cp /etc/slurm/slurm.conf.ohpc /etc/slurm/slurm.conf
###start slurm###
perl -pi -e "s/ControlMachine=\S+/ControlMachine=${sms_name}/" /etc/slurm/slurm.conf
##
perl -pi -e "s/JobCompType=jobcomp\/none/#JobCompType=jobcomp\/none/" /etc/slurm/slurm.conf
perl -pi -e 's/NodeName=/##NodeName=/' /etc/slurm/slurm.conf
perl -pi -e 's/PartitionName=/##PartitionName=/' /etc/slurm/slurm.conf
systemctl enable munge
systemctl enable slurmctld
### slurm.conf need to be modified.

### install sql
yum -y -q install mariadb*
# 假设机器的/home分区是个SSD的大分区，datadir设置为/home/mysql
# mkdir -p /home/mysql
# chown mysql:mysql /home/mysql
# sed -i '/^datadir/s/^.*$/datadir=\/home\/mysql/g' /etc/my.cnf
# 启动mysql进程
systemctl start mariadb.service
# 将mysql设置为开机自启动
systemctl enable mariadb.service
# 设置mysql root密码
mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('78g*tw23.ysq');"
# 添加slurmdb 数据库用户
mysql -uroot -p'78g*tw23.ysq' -e"CREATE USER 'slurmdb'@'localhost' IDENTIFIED BY 'slurmdb123456';"
mysql -uroot -p'78g*tw23.ysq' -e"REVOKE ALL PRIVILEGES ON *.* FROM 'slurmdb'@'localhost';"
mysql -uroot -p'78g*tw23.ysq' -e"CREATE DATABASE slurm_acct_db;"
mysql -uroot -p'78g*tw23.ysq' -e"CREATE DATABASE slurm_jobcomp_db;"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'localhost' IDENTIFIED BY 'slurmdb123456';"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_jobcomp_db.* TO 'slurmdb'@'localhost' IDENTIFIED BY 'slurmdb123456';"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'${sms_name}' IDENTIFIED BY 'slurmdb123456';"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_jobcomp_db.* TO 'slurmdb'@'${sms_name}' IDENTIFIED BY 'slurmdb123456';"
mysql -uroot -p'78g*tw23.ysq' -e"FLUSH PRIVILEGES"

## 配置slurmdb
systemctl enable slurmdbd
/bin/cp /etc/slurm/slurmdbd.conf.example /etc/slurm/slurmdbd.conf
perl -pi -e "s/StoragePass=\S+/StoragePass=slurmdb123456/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/StorageUser=\S+/StorageUser=slurmdb/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/DbdAddr=localhost/DbdAddr=${sms_ip}/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/DbdHost=localhost/DbdHost=${sms_name}/" /etc/slurm/slurmdbd.conf


chown slurm.slurm /etc/slurm/slurmdbd.conf
mkdir -p /var/log/slurm
systemctl start slurmdbd

chown slurm.root /etc/slurm/slurm.conf
chmod 660 /etc/slurm/slurm.conf
perl -pi -e "s/#AccountingStorageHost=/AccountingStorageHost=${sms_name}/"   /etc/slurm/slurm.conf       #指明slurndbd的hostname
perl -pi -e "s/AccountingStorageHost/\nAccountingStoragePort=6819\nAccountingStorageHost/"    /etc/slurm/slurm.conf         #使用的端口，默认6819
perl -pi -e "s/#AccountingStorageType=\S+/AccountingStorageType=accounting_storage\/slurmdbd/"   /etc/slurm/slurm.conf    #使用slurmdbd收集信息


perl -pi -e "s/#JobCompType/JobCompHost=${sms_name}\n#JobCompType/"     /etc/slurm/slurm.conf            #安装mysql的hostname
perl -pi -e "s/#JobCompLoc=/JobCompLoc=\/var\/log\/slurm\/slurm_jobcomp.log/"  /etc/slurm/slurm.conf   #日志信息
perl -pi -e "s/JobCompHost=${sms_name}/JobCompHost=${sms_name}\nJobCompPass=slurmdb123456/"    /etc/slurm/slurm.conf    #mysql密码
perl -pi -e "s/JobCompHost=${sms_name}/JobCompHost=${sms_name}\nJobCompPort=3306/"   /etc/slurm/slurm.conf      #mysql端口
perl -pi -e "s/JobCompType=\S+/JobCompType=jobcomp\/mysql/"   /etc/slurm/slurm.conf      #使用mysql记录完成的任务信息
perl -pi -e "s/JobCompHost=${sms_name}/JobCompHost=${sms_name}\nJobCompUser=slurmdb/"    /etc/slurm/slurm.conf     #mysql用户
perl -pi -e "s/#JobAcctGatherType=\S+/JobAcctGatherType=jobacct_gather\/linux/" /etc/slurm/slurm.conf
perl -pi -e "s/ProctrackType=\S+/ProctrackType=proctrack\/linuxproc/" /etc/slurm/slurm.conf
perl -pi -e "s/#JobAcctGatherFrequency=\S+/JobAcctGatherFrequency=30/" /etc/slurm/slurm.conf

echo "NodeName=${sms_name} Sockets=1 CoresPerSocket=2 ThreadsPerCore=1 State=UNKNOWN" >> /etc/slurm/slurm.conf
echo "PartitionName=head Nodes=${sms_name} Default=YES MaxTime=24:00:00 State=UP Oversubscribe=EXCLUSIVE" >> /etc/slurm/slurm.conf

systemctl start munge
systemctl start slurmctld

### enable slurmd in sms 
yum -y -q install ohpc-slurm-client
#systemctl  enable slurmd
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" > /etc/sysconfig/slurmd

### add http repo for compute nodes 
cat >/etc/httpd/conf.d/repo.conf <<'EOF'
AliasMatch ^/opt/repo/(.*)$ "/opt/repo/$1"
<Directory "/opt/repo">
    Options Indexes FollowSymLinks Includes MultiViews
    AllowOverride None
    Require all granted
</Directory>
EOF
systemctl restart httpd
####


#### Install ClusterShell
yum -y -q install clustershell
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
##echo "/opt/repo *(ro,no_subtree_check,fsid=12)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
systemctl enable nfs-server


#####################         ###############################
## add nis server 
yum install -y -q rpcbind yp-tools ypbind ypserv 
systemctl enable rpcbind ypserv ypxfrd yppasswdd
##add ypdomainname
echo "NISDOMAIN=${domain_name}" >> /etc/sysconfig/network
systemctl start rpcbind ypserv ypxfrd yppasswdd
### update nis database 
sleep 6
echo y | /usr/lib64/yp/ypinit -m
sleep 6
###  ctrl-d to continue
systemctl restart rpcbind ypserv ypxfrd yppasswdd
###########
