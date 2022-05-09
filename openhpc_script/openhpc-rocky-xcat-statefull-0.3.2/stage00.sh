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
dep-packages.tar
kickstart-powertools.tar
openhpc.tar
xcat.tar
l_BaseKit_p_2022.1.2.146_offline.sh
l_HPCKit_p_2022.1.2.117_offline.sh 
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

if [ ! -e ${iso_path}/Rocky-8.5-x86_64-dvd1.iso ] ; then
   echo "${iso_path}/Rocky-8.5-x86_64-dvd1.iso is not exist!!!"
   exit
fi

mkdir -p /opt/repo/rocky
mkdir -p /media/Rocky
mount -o loop ${iso_path}/Rocky-8.5-x86_64-dvd1.iso   /media/Rocky
cp -r /media/Rocky/*  /opt/repo/rocky

### for virmachine mount cdrom device
# mkdir /media/Rocky
# mount -t auto /dev/cdrom /media/Rocky
# cp -r /media/Rocky/*  /opt/repo/rocky


tar --no-same-owner -xf ${package_dir}/dep-packages.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/kickstart-powertools.tar -C /opt/repo/rocky
tar --no-same-owner -xf ${package_dir}/openhpc.tar -C /opt/repo
tar --no-same-owner -xf ${package_dir}/xcat.tar -C /opt/repo


# find /opt/repo/rocky/epel -type f -exec chmod 444 {} \;
# chown -R root.root /opt/repo/rocky

cat <<EOF > /etc/yum.repos.d/Rocky-local.repo
# Rocky-local.repo
#
# You can use this repo to install items directly off the installation local.
# Verify your mount point matches one of the below file:// paths.

[local-baseos]
name=Rocky Linux \$releasever - local - BaseOS
baseurl=file:///opt/repo/rocky/BaseOS
gpgcheck=0
enabled=1

[local-appstream]
name=Rocky Linux \$releasever - local - AppStream
baseurl=file:///opt/repo/rocky/AppStream
gpgcheck=0
enabled=1

[local-powertools]
name=Rocky Linux \$releasever - local - PowerTools
baseurl=file:///opt/repo/rocky/kickstart-powertools
gpgcheck=0
enabled=1

[local-dep-packages]
name=Rocky Linux \$releasever - local - dep-packages
baseurl=file:///opt/repo/rocky/dep-packages
gpgcheck=0
enabled=1

EOF

## /bin/cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/
## chmod 644 /etc/yum.repos.d/Rocky-local.repo
/opt/repo/openhpc/make_repo.sh
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

