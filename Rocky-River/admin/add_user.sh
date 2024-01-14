#!/bin/sh
if [ -e ./env.text ]; then
    source ./env.text  ## 这里要添加指定家目录的设置
fi

echo "只能一次添加单个用户"

if [ -z $1 ]; then
    echo "未输入用户名，退出！"
    exit
fi

adduser $1

make -C /var/yp 

echo "用户添加完成，请手动初始化用户密码"

# 这里可以写一点自动初始化密码的脚本

# 这里可以写上slurm的相关配置

