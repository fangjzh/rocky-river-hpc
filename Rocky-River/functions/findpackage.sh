#!/bin/sh

iso_name=Rocky-8.9-x86_64-dvd1.iso

res_tmp=($(find /root /mnt /media /run/media -name ${iso_name}))
if [ -z ${res_tmp[0]} ]; then
    echo "没有找到系统镜像！"
    echo "请将镜像放到/root，/mnt，/media，/run/media目录或者子目录下！"
    exit 11
else
    iso_path_f=$(realpath ${res_tmp[0]})
    iso_path=${iso_path_f%/*}
fi

res_tmp=($(find /root /mnt /media /run/media -name dep-packages.tar))
if [ -z ${res_tmp[0]} ]; then
    echo "没有找到安装包文件！"
    echo "请将镜像放到/root，/mnt，/media，/run/media目录或者子目录下！"
    exit 12
else
    package_dir_f=$(realpath ${res_tmp[0]})
    package_dir=${package_dir_f%/*}
fi

#### 检查所有安装包 ###
filelist=(
    dep-packages.tar
    kickstart-powertools.tar
    openhpc.tar
    xcat.tar
)

for ifile in ${filelist[@]}; do
    if [ ! -e ${package_dir}/${ifile} ]; then
        echo "安装包 ${ifile} 不存在!!!"
        exit 13
    fi
done

echo "安装文件已全部找到！"
echo "### 安装文件位置：" >>env.text
echo "export package_dir=${package_dir}" >>env.text
echo "export iso_path=${iso_path}" >>env.text
echo "export iso_name=${iso_name}" >>env.text

exit 0
