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

### 配置文件产生起始
### 删除先前产生的配置文件
if [ -e env.text ] ; then
    rm env.text
fi

#########################################
#############-----int 0-----#############
#########################################
### 检查脚本文件的权限与完整性
filelist=(
reg_name.sh
reg_network.sh
user_define.sh
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
####-----------end int 0-------------####

#########################################
#############-----int 1-----#############
#########################################
### 寻找安装包文件的位置,判断其完整性
./functions/findpackage.sh  findpackage.log
if [ $? -ne 0 ]; then
    exit
fi
####-----------end int 1-------------####

#########################################
#############-----int 2-----#############
#########################################
### 设置环境变量，生成 env.text 文件
### 确定集群名字
./functions/reg_name.sh

### 确定集群网络参数
./functions/reg_network.sh
####-----------end int 2-------------####


#########################################
#############-----int 3-----#############
#########################################
### 生成 Install.sh
### 产生本地 repo >> Install.sh
echo "" > Install.sh
echo "./functions/make_repo.sh" >> Install.sh
### 设置管理节点时区、防火墙等 >> Install.sh
echo "./functions/set_headnode.sh" >> Install.sh
### 设置网络 >> Install.sh
echo "./functions/create_network.sh" >> Install.sh

### 目前到了 stage01.sh 第54行，但是前面的功能未经充分测试
#### 未完待续。。。。 

### 添加自定义设置
echo "./functions/user_define.sh  user_define.log" >> Install.sh
####-----------end int 3-------------####





