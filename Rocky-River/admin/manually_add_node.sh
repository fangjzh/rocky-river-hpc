#!/bin/sh
## 这个脚本还未完成，作为一个参考脚本
. /etc/profile.d/xcat.sh

if [ -z $1 ]; then
    echo "未输入节点信息，退出！"
    exit
fi

## 这里是需要手动修改的部分
nodedefine cnode001 groups=everything,compute net.hwaddr=00:50:56:2A:F8:2A net.ipv4_address=10.0.1.2
confluent2hosts -a compute
nodedeploy -n cnode001 -p rocky-9.6-x86_64-mydefinition