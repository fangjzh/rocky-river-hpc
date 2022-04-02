## 首先，DVD里边有的可以不下载，分别是 BaseOS和AppStream
## DVD 下载地址：
## https://mirrors.sjtug.sjtu.edu.cn/rocky/8.5/isos/x86_64/
if [ ! -e ./Rocky-8.5-x86_64-dvd1.iso ] ; then
  echo "${ifile} not exist."
#  wget https://mirrors.sjtug.sjtu.edu.cn/rocky/8.5/isos/x86_64/Rocky-8.5-x86_64-dvd1.iso
fi

## -------------
## -------------
## 然后是其他三个目录extras/PowerTools/epel
## 可以用同步法下载至本地

## 设置缓存保留
cat <<EOF >> /etc/yum.conf 
keepcache=1
cachedir=/var/cache/yum/\$basearch/\$releasever
EOF

### 修改源 base os 、appstream 以及powertools 为 kickstart，也就是rocky Linux当时release的状态
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

cat <<EOF > /etc/yum.repos.d/Rocky-kickstart.repo
# Rocky-local.repo
#
# You can use this repo to install items directly off the installation local.
# Verify your mount point matches one of the below file:// paths.

[kickstart-baseos]
name=Rocky Linux \$releasever - kickstart - BaseOS
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/BaseOS/\$basearch/kickstart/
gpgcheck=0
enabled=1

[kickstart-appstream]
name=Rocky Linux \$releasever - kickstart - AppStream
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/AppStream/\$basearch/kickstart/
gpgcheck=0
enabled=1

[kickstart-powertools]
name=Rocky Linux \$releasever - kickstart - PowerTools
baseurl=https://mirrors.aliyun.com/rockylinux/\$releasever/PowerTools/\$basearch/kickstart/
gpgcheck=0
enabled=1

EOF


yum makecache

yum -y install yum-utils createrepo


### 
mkdir -p /opt/repo/rocky
reposync --repoid=kickstart-powertools  --exclude 'java-*debug*' --exclude 'dotnet*' -p /opt/repo/rocky/
createrepo /opt/repo/rocky/kickstart-powertools

cd /opt/repo/rocky
tar -cf /root/kickstart-powertools.tar kickstart-powertools
cd ~


### 添加epel和fish源
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-archive-8.repo
wget -O /etc/yum.repos.d/fish.repo https://download.opensuse.org/repositories/shells:/fish:/release:/3/CentOS_8/shells:fish:release:3.repo


### 添加xcat 和 openhpc 本地源
if [ ! -e ./OpenHPC-2.4.EL_8.x86_64.tar ] ; then
  echo "${ifile} not exist."
  wget http://repos.openhpc.community/dist/2.4/OpenHPC-2.4.EL_8.x86_64.tar
fi
## on page https://xcat.org/download.html
if [ ! -e ./xcat-core-2.16.3-linux.tar.bz2 ] ; then
  echo "${ifile} not exist."
  wget https://xcat.org/files/xcat/xcat-core/2.16.x_Linux/xcat-core/xcat-core-2.16.3-linux.tar.bz2
fi

if [ ! -e ./xcat-dep-2.16.3-linux.tar.bz2 ] ; then
  echo "${ifile} not exist."
  wget https://xcat.org/files/xcat/xcat-dep/2.x_Linux/xcat-dep-2.16.3-linux.tar.bz2
fi

##
mkdir -p /opt/repo/openhpc
tar -xf ./OpenHPC-2.4.EL_8.x86_64.tar  -C /opt/repo/openhpc
rm -f /opt/repo/openhpc/EL_8/x86_64/trilinos-*
rm -f /opt/repo/openhpc/EL_8/updates/x86_64/trilinos-*
createrepo /opt/repo/openhpc/EL_8/updates/
createrepo /opt/repo/openhpc/EL_8/
/opt/repo/openhpc/make_repo.sh

##
cd /opt/repo/
tar -cf /root/openhpc.tar openhpc
cd ~

mkdir -p /opt/repo/xcat
tar -xjf ./xcat-dep-2.16.3-linux.tar.bz2 -C /opt/repo/xcat
tar -xjf ./xcat-core-2.16.3-linux.tar.bz2 -C /opt/repo/xcat
cd  /opt/repo/xcat/xcat-dep
rm -rf rh7 rh8/ppc64le/ rh8/ppc64le/ sles12/ sles15/
cd ~
/opt/repo/xcat/xcat-dep/rh8/x86_64/mklocalrepo.sh
/opt/repo/xcat/xcat-core/mklocalrepo.sh

cd /opt/repo/
tar -cf /root/xcat.tar xcat
cd ~

## 产生依赖文件缓存
yum -y install --downloadonly fish

## yum repolist
## yum list --repo xxxxxx
yum list --repo xcat-dep | grep xcat-dep | awk '{printf "%s ",$1}' > xcat-dep.list
yum list --repo xcat-core | grep xcat-core | awk '{printf "%s ",$1}' > xcat-core.list
yum list --repo OpenHPC-local | grep OpenHPC-local |grep -v aarch64 |grep -v '.src '| awk '{printf "%s ",$1}' > ohpc.list
yum list --repo OpenHPC-local-updates | grep OpenHPC-local-updates |grep -v aarch64 |grep -v '.src '| awk '{printf "%s ",$1}' > ohpc-updates.list

cat xcat-core.list | xargs yum -y install --downloadonly --skip-broken
cat xcat-dep.list | xargs yum -y install --downloadonly --skip-broken
cat ohpc.list | xargs yum -y install --downloadonly --skip-broken
cat ohpc-updates.list | xargs yum -y install --downloadonly --skip-broken
## 事实证明，本地的file repo，文件不会被下载

## 打包缓存为repo
mkdir -p dep-packages
dir=`find /var/cache/yum/ -name 'epel*' -type d`
cp -r ${dir}/packages/ dep-packages/

dir=`find /var/cache/yum/ -name 'shells*' -type d`
cp -r ${dir}/packages/ dep-packages/
createrepo dep-packages
tar -cf dep-packages.tar dep-packages/

