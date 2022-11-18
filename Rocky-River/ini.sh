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
if [ -e env.text ]; then
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

for ifile in ${filelist[@]}; do
    if [ ! -e ./functions/${ifile} ]; then
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
./functions/findpackage.sh
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

echo "#!/bin/bash" >Install.sh
cat <<EOF >>Install.sh
if [ ! -e ./env.text ]; then
    echo "错误：安装环境变量文件 env.text 未产生！"
    exit 10
else
    source ./env.text
fi
EOF
### 产生本地 repo >> Install.sh（这里依赖httpd，已经添加）
echo "### 产生本地 repo" >>Install.sh
echo "./functions/make_repo.sh" >>Install.sh

### 设置管理节点时区、防火墙等 >> Install.sh
echo "### 设置管理节点时区、防火墙等" >>Install.sh
echo "./functions/set_headnode.sh" >>Install.sh

### 设置网络 >> Install.sh
echo "### 设置网络" >>Install.sh
echo "./functions/setup_network.sh" >>Install.sh

### 安装ntp-server >> Install.sh
echo "### 安装ntp-server" >>Install.sh
echo "./functions/setup_ntp.sh" >>Install.sh

### 安装 mysql >> Install.sh
echo "### 安装 mysql" >>Install.sh
echo "./functions/setup_sql.sh" >>Install.sh

## 安装 ohpc、xcat >> Install.sh
echo "## 安装 ohpc、xcat" >>Install.sh
echo "./functions/setup_ohpc_xcat.sh" >>Install.sh

## 安装 slurm >> Install.sh
echo "## 安装 slurm " >>Install.sh
echo "./functions/setup_slurm.sh" >>Install.sh

## 安装 nis >> Install.sh
echo "## 安装 nis" >>Install.sh
echo "./functions/setup_nis.sh" >>Install.sh

## 安装 nfs >> Install.sh (这里需要有ohpc产生的目录/opt/ohpc/pub)
echo "## 安装 nfs " >>Install.sh
echo "./functions/setup_nfs.sh" >>Install.sh

## 安装 cluster shell >> Install.sh
echo "## 安装 cluster shel" >>Install.sh
echo "./functions/setup_clustershell.sh" >>Install.sh

## 安装编译工具 >> Install.sh
echo "## 安装编译工具" >>Install.sh
echo "./functions/setup_devtools.sh" >>Install.sh

### 添加自定义设置
echo "### 添加自定义设置" >>Install.sh
echo "./functions/user_define.sh" >>Install.sh
chmod +x Install.sh
####-----------end int 3-------------####

echo "接下来请执行 Install.sh 脚本"