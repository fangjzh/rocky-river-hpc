#!/bin/bash

################################
#####       功能规划       #####
################################
### 交互脚本，输入基本信息，产生Install.sh脚本以及env.text
### Install.sh脚本调用多个函数，而全局变量存储在env.text里边，通过source 命令生效
### 各个功能脚本放在functions文件夹里边
### 脚本有出错接着执行的功能
### 脚本应添加检测功能
### 要产生一个添加用户脚本，放在root目录
### 同样地添加节点脚本
##################################

### 检查脚本文件的权限与完整性
filelist=(
cname.sh
#cnetwork.sh
#osprovision.sh
)

for ifile in ${filelist[@]}
do
  if [ ! -e ./functions/${ifile} ] ; then
  echo "${ifile} 文件不存在!!!"
  exit 
fi
done

chmod +x ./functions/*.sh

if [ -e env.text ] ; then
rm env.text
fi

### 寻找安装包文件的位置,判断其完整性
./functions/findpackage.sh
if [ $? -ne 0 ]; then
exit
fi

### 设置集群名字
./functions/cname.sh $cname

### 设置集群内网IP
./functions/cnetwork.sh






