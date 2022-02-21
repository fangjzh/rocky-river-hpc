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
appstream.tar
baseos.tar       
extras.tar
powertools.tar
epel.tar 
l_BaseKit_p_2022.1.2.146_offline.sh
l_HPCKit_p_2022.1.2.117_offline.sh 
OpenHPC-2.4.EL_8.x86_64.tar 
xcat-core-2.16.3-linux.tar.bz2 
xcat-dep-2.16.3-linux.tar.bz2 
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

# if [ ! -e ${iso_path}/Rocky-8.5-x86_64-dvd1.iso ] ; then
#   echo "${iso_path}/Rocky-8.5-x86_64-dvd1.iso is not exist!!!"
#   exit
# fi
mkdir -p /opt/repo/rocky
# mkdir -p /root/iso_mnt
# mount -o loop ${iso_path}/Rocky-8.5-x86_64-dvd1.iso   /root/iso_mnt
# cp -r /root/iso_mnt/*  /opt/repo/rocky

# for virmachine mount cdrom device
# mkdir /mnt/cdrom
# mount -t auto /dev/cdrom /mnt/cdrom
# cp -r /mnt/cdrom/*  /opt/repo/rocky

##cp -r ${package_dir}/Rocky-package/* /opt/repo/rocky

tar --no-same-owner -xf ${package_dir}/baseos.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/appstream.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/epel.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/extras.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/powertools.tar -C /opt/repo/rocky
## mv /opt/repo/rocky/RockyOs/* /opt/repo/rocky
## rm -rf /opt/repo/rocky/RockyOs

# find /opt/repo/rocky/epel -type f -exec chmod 444 {} \;
# find /opt/repo/rocky/extras -type f -exec chmod 444 {} \;
# find /opt/repo/rocky/PowerTools -type f -exec chmod 444 {} \;
# find /opt/repo/rocky/epel -type d -exec chmod 555 {} \;
# find /opt/repo/rocky/extras -type d -exec chmod 555 {} \;
# find /opt/repo/rocky/PowerTools -type d -exec chmod 555 {} \;
# chown -R root.root /opt/repo/rocky

cat <<EOF > /etc/yum.repos.d/Rocky-local.repo
# Rocky-local.repo
#
# You can use this repo to install items directly off the installation local.
# Verify your mount point matches one of the below file:// paths.

[local-baseos]
name=Rocky Linux $releasever - local - BaseOS
baseurl=file:///opt/repo/rocky/baseos
gpgcheck=0
enabled=1

[local-appstream]
name=Rocky Linux $releasever - local - AppStream
baseurl=file:///opt/repo/rocky/appstream
gpgcheck=0
enabled=1

[local-extras]
name=Rocky Linux $releasever - local - Extras
baseurl=file:///opt/repo/rocky/extras
gpgcheck=0
enabled=1

[local-powertools]
name=Rocky Linux $releasever - local - PowerTools
baseurl=file:///opt/repo/rocky/powertools
gpgcheck=0
enabled=1

[local-epel]
name=Rocky Linux $releasever - local - epel
baseurl=file:///opt/repo/rocky/epel
gpgcheck=0
enabled=1

EOF

## /bin/cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/
## chmod 644 /etc/yum.repos.d/Rocky-local.repo

mkdir -p /opt/repo/openhpc
tar -xf ${package_dir}/OpenHPC-2.4.EL_8.x86_64.tar  -C /opt/repo/openhpc
/opt/repo/openhpc/make_repo.sh

mkdir -p /opt/repo/xcat
tar -xjf ${package_dir}/xcat-dep-2.16.3-linux.tar.bz2 -C /opt/repo/xcat
tar -xjf ${package_dir}/xcat-core-2.16.3-linux.tar.bz2 -C /opt/repo/xcat
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
cat /etc/yum.repos.d/Rocky-local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' > /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/OpenHPC.local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-core.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-dep.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo

