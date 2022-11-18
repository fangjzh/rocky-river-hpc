#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置slurm - - - - - - - -"

#### install slurm ######
yum -y -q install mailx munge ohpc-slurm-server
systemctl enable munge

# 添加slurmdb 数据库用户
mysql -uroot -p'78g*tw23.ysq' -e"CREATE USER 'slurmdb'@'localhost' IDENTIFIED BY 'slurmdb123456';"
#mysql -uroot -p'78g*tw23.ysq' -e"CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'slurm_jcomp';"
mysql -uroot -p'78g*tw23.ysq' -e"REVOKE ALL PRIVILEGES ON *.* FROM 'slurmdb'@'localhost';"
mysql -uroot -p'78g*tw23.ysq' -e"CREATE DATABASE slurm_acct_db;"
#mysql -uroot -p'78g*tw23.ysq' -e"CREATE DATABASE slurm_jobcomp_db;"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'localhost' IDENTIFIED BY 'slurmdb123456';"
#mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_jobcomp_db.* TO 'slurm'@'localhost' IDENTIFIED BY 'slurm_jcomp';"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurmdb'@'${sms_name}' IDENTIFIED BY 'slurmdb123456';"
#mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON slurm_jobcomp_db.* TO 'slurm'@'${sms_name}' IDENTIFIED BY 'slurm_jcomp';"
mysql -uroot -p'78g*tw23.ysq' -e"FLUSH PRIVILEGES"

############# 配置slurmdb  ################
systemctl enable slurmdbd
/bin/cp /etc/slurm/slurmdbd.conf.example /etc/slurm/slurmdbd.conf
chown slurm.slurm /etc/slurm/slurmdbd.conf
perl -pi -e "s/StoragePass=\S+/StoragePass=slurmdb123456/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/StorageUser=\S+/StorageUser=slurmdb/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/DbdAddr=localhost/DbdAddr=${sms_ip}/" /etc/slurm/slurmdbd.conf
perl -pi -e "s/DbdHost=localhost/DbdHost=${sms_name}/" /etc/slurm/slurmdbd.conf

############# 配置slurm server ############
systemctl enable slurmctld
### /bin/cp /etc/slurm/slurm.conf.ohpc /etc/slurm/slurm.conf
### chown slurm.root /etc/slurm/slurm.conf
### chmod 644 /etc/slurm/slurm.conf
### 
### perl -pi -e "s/ControlMachine=\S+/ControlMachine=${sms_name}/" /etc/slurm/slurm.conf
### ##
### perl -pi -e "s/JobCompType=jobcomp\/none/#JobCompType=jobcomp\/none/" /etc/slurm/slurm.conf
### perl -pi -e 's/NodeName=/##NodeName=/' /etc/slurm/slurm.conf
### perl -pi -e 's/PartitionName=/##PartitionName=/' /etc/slurm/slurm.conf
### 
### perl -pi -e "s/#AccountingStorageHost=/AccountingStorageHost=${sms_name}/" /etc/slurm/slurm.conf                     #指明slurndbd的hostname
### perl -pi -e "s/AccountingStorageHost/\nAccountingStoragePort=6819\nAccountingStorageHost/" /etc/slurm/slurm.conf     #使用的端口，默认6819
### perl -pi -e "s/#AccountingStorageType=\S+/AccountingStorageType=accounting_storage\/slurmdbd/" /etc/slurm/slurm.conf #使用slurmdbd收集信息
### 
### mkdir -p /var/log/slurm
### perl -pi -e "s/#JobCompLoc=/JobCompLoc=\/var\/log\/slurm_jobcomp.log/" /etc/slurm/slurm.conf #日志信息
### 
### perl -pi -e "s/#JobAcctGatherType=\S+/JobAcctGatherType=jobacct_gather\/linux/" /etc/slurm/slurm.conf
### perl -pi -e "s/ProctrackType=\S+/ProctrackType=proctrack\/linuxproc/" /etc/slurm/slurm.conf
### perl -pi -e "s/#JobAcctGatherFrequency=\S+/JobAcctGatherFrequency=30/" /etc/slurm/slurm.conf
### 
### echo "NodeName=${sms_name} Sockets=1 CoresPerSocket=2 ThreadsPerCore=1 State=UNKNOWN" >>/etc/slurm/slurm.conf
### echo "PartitionName=head Nodes=${sms_name} Default=YES MaxTime=168:00:00 State=UP Oversubscribe=YES" >>/etc/slurm/slurm.conf

/bin/cp ./sample_files/slurmconf_ref/slurm.conf /etc/slurm/slurm.conf
chown slurm.root /etc/slurm/slurm.conf
chmod 644 /etc/slurm/slurm.conf
perl -pi -e "s/cjhpc/${sms_name}/" /etc/slurm/slurm.conf
##

systemctl start munge
systemctl start slurmdbd
systemctl start slurmctld

############ 将头节点加入计算 ##############
yum -y -q install ohpc-slurm-client
#systemctl  enable slurmd
echo SLURMD_OPTIONS="--conf-server ${sms_ip}" >/etc/sysconfig/slurmd
echo "NodeName=${sms_name} Sockets=1 CoresPerSocket=2 ThreadsPerCore=1 State=UNKNOWN" >>/etc/slurm/slurm.conf
echo "PartitionName=head Nodes=${sms_name} Default=YES MaxTime=168:00:00 State=UP Oversubscribe=YES" >>/etc/slurm/slurm.conf
systemctl enable slurmd

## This kind of perl command should be changed !!!
## a fixed template should be prepared, sence the default service file in different edition
## is different
# perl -pi -e "s/munge.service.*/munge.service mariadb.service/" /usr/lib/systemd/system/slurmdbd.service
# perl -pi -e "s/remote-fs.target.*/network-online.target remote-fs.target slurmctld.service/" /usr/lib/systemd/system/slurmd.service
# perl -pi -e "s/munge.service.*/network-online.target munge.service slurmdbd.service named.service/" /usr/lib/systemd/system/slurmctld.service
# perl -pi -e 'print"Wants=network-online.target  slurmdbd.service named.service\n" if $. == 4' /usr/lib/systemd/system/slurmctld.service
# perl -pi -e 'print"Wants=network-online.target slurmctld.service named.service\n" if $. == 4' /usr/lib/systemd/system/slurmd.service

mkdir ./back_slurm_service
/bin/cp /usr/lib/systemd/system/slurm*.service ./back_slurm_service
/bin/cp ./sample_files/slurmconf_ref/slurm*.service /usr/lib/systemd/system/
chmod 644 /usr/lib/systemd/system/slurm*.service
systemctl daemon-reload
systemctl enable slurmctld

echo "-->执行 $0 : 安装设置slurm 完毕 + = + = + = + = + ="

echo "$0 执行完成！" >${0##*/}.log
