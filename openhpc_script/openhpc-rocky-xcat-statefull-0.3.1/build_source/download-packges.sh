## 首先，DVD里边有的可以不下载，分别是 BaseOS和AppStream
## DVD 下载地址：
## https://mirrors.sjtug.sjtu.edu.cn/rocky/8.5/isos/x86_64/

wget https://mirrors.sjtug.sjtu.edu.cn/rocky/8.5/isos/x86_64/Rocky-8.5-x86_64-dvd1.iso

## -------------
## -------------
## 然后是其他三个目录extras/PowerTools/epel
## 可以用同步法下载至本地

## ---- extras and PowerTools ----
mkdir -p /data/repo

mkdir repoback
cp /etc/yum.repos.d/*.repo repoback

sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
    -i.bak \
    /etc/yum.repos.d/Rocky-*.repo

yum clean all
#yum autoremove
#rm -rf /var/cache/yum
yum makecache

yum -y install yum-utils createrepo

## 如加参数 -n 表示如果有多个版本只下载最新的包，这种方式会导致完全本地后装软件依赖缺失
reposync --repoid=extras --repoid=powertools --download-metadata -p /data/repo/
reposync --repoid=baseos --repoid=appstream --download-metadata -p /data/repo/


## ---- epel ----
mkdir -p /data/repo/epel
rsync -vrt --bwlimit=3000 --exclude=debug/ rsync://rsync.mirrors.ustc.edu.cn/epel/8/Everything/x86_64/  /data/repo/epel/
createrepo --update /data/repo/epel/
## ----- 产生repodata 的数据库 ------   


#createrepo --update /data/repo/baseos/
#createrepo --update /data/repo/appstream/ 
#createrepo --update /data/repo/extras/
#createrepo --update /data/repo/powertools/ 

## createrepo --update /data/repo/epel/

## 然后把这些都打包例如：
## tar -cvf ../RockyHPC-Packages/powertools.tar powertools/
cd /data/repo
tar -cvf baseos.tar  baseos
tar -cvf appstream.tar  appstream
tar -cvf extras.tar extras
tar -cvf powertools.tar powertools
tar -cvf epel.tar epel



## -------------
## -------------
## 然后是获取openhpc 和 xcat 的包

## on page http://repos.openhpc.community/dist/2.4/
wget http://repos.openhpc.community/dist/2.4/OpenHPC-2.4.EL_8.x86_64.tar

## on page https://xcat.org/download.html
wget https://xcat.org/files/xcat/xcat-core/2.16.x_Linux/xcat-core/xcat-core-2.16.3-linux.tar.bz2
wget https://xcat.org/files/xcat/xcat-dep/2.x_Linux/xcat-dep-2.16.3-linux.tar.bz2


##---------
##---------


## 然后是下载Intel的编译器套件
## https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html
