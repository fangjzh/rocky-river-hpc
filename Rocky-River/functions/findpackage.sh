#!/bin/bash

iso_name=Rocky-8.6-x86_64-dvd1.iso

res_tmp=(`find /root /mnt /media /run/media -name ${iso_name}`)
if [ -z ${res_tmp[0]} ]; then
  echo "没有找到系统镜像！"
exit 11
else
  iso_path_f=`realpath  ${res_tmp[0]}`
  iso_path=${iso_path_f%/*}
fi

res_tmp=(`find /root /mnt /media /run/media -name dep-packages.tar`)
if [ -z ${res_tmp[0]} ]; then
  echo "没有找到安装包文件！"
  exit 12
else
  package_dir_f=`realpath  ${res_tmp[0]}`
  package_dir=${package_dir_f%/*}
fi

#### 检查所有安装包 ###
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
  echo "安装包 ${ifile} 不存在!!!"
  exit 13
fi
done

echo "安装文件已找到！"
echo "### 安装文件位置：" >> env.text
echo "export package_dir=${package_dir}" >> env.text
echo "export iso_path=${iso_path}" >> env.text

