#!/bin/sh
source ./env.sh

if [ $? != 0 ]; then
echo "no env.sh find. error!"
exit
fi

echo " ## user define " >> /root/.bashrc
echo "unset command_not_found_handle" >> /root/.bashrc
source /root/.bashrc


#### check files ###
filelist=(
backup_xcat_hack.tgz
epel.tar
l_BaseKit_p_2021.3.0.3219_offline.sh
l_HPCKit_p_2021.3.0.3230_offline.sh
OpenHPC-2.3.CentOS_8.x86_64.tar
Rocky-local.repo
RockyOs.tgz
xcat/xcat-core-2.16.2-linux.tar.bz2  
xcat/xcat-dep-2.16.2-linux.tar.bz2
)

for ifile in ${filelist[@]}
do
  if [ ! -e ${package_dir}/${ifile} ] ; then
  echo "${ifile} is not exist!!!"
  exit
fi
done

###make local repo####
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

if [ ! -e ${iso_path}/Rocky-8.4-x86_64-dvd1.iso ] ; then
  echo "${iso_path}/Rocky-8.4-x86_64-dvd1.iso is not exist!!!"
  exit
fi
mkdir -p /opt/repo/rocky
mkdir -p /root/iso_mnt
mount -o loop ${iso_path}/Rocky-8.4-x86_64-dvd1.iso   /root/iso_mnt
cp -r /root/iso_mnt/*  /opt/repo/rocky

# for virmachine mount cdrom device
# mkdir /mnt/cdrom
# mount -t auto /dev/cdrom /mnt/cdrom
# cp -r /mnt/cdrom/*  /opt/repo/rocky

##cp -r ${package_dir}/Rocky-package/* /opt/repo/rocky

tar --no-same-owner -xf ${package_dir}/epel.tar -C /opt/repo/rocky
tar --no-same-owner -xzf ${package_dir}/RockyOs.tgz -C /opt/repo/rocky
mv /opt/repo/rocky/RockyOs/* /opt/repo/rocky
rm -rf /opt/repo/rocky/RockyOs

find /opt/repo/rocky/epel -type f -exec chmod 444 {} \;
find /opt/repo/rocky/extras -type f -exec chmod 444 {} \;
find /opt/repo/rocky/PowerTools -type f -exec chmod 444 {} \;
find /opt/repo/rocky/epel -type d -exec chmod 555 {} \;
find /opt/repo/rocky/extras -type d -exec chmod 555 {} \;
find /opt/repo/rocky/PowerTools -type d -exec chmod 555 {} \;
# chown -R root.root /opt/repo/rocky

/bin/cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/
chmod 644 /etc/yum.repos.d/Rocky-local.repo

mkdir -p /opt/repo/openhpc
tar -xf ${package_dir}/OpenHPC-2.3.CentOS_8.x86_64.tar -C /opt/repo/openhpc
/opt/repo/openhpc/make_repo.sh

mkdir -p /opt/repo/xcat
tar -xjf ${package_dir}/xcat/xcat-dep-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
tar -xjf ${package_dir}/xcat/xcat-core-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
/opt/repo/xcat/xcat-dep/rh8/x86_64/mklocalrepo.sh
/opt/repo/xcat/xcat-core/mklocalrepo.sh


yum clean all
yum makecache

if [ $? != 0 ]; then
echo "make repo error!"
exit
else
echo "make repo succeed !"
fi


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

