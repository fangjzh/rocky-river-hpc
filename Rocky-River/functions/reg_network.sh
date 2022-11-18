#!/bin/bash
# blog: http://lizhenliang.blog.51cto.com

## IP检查
function check_ip() {
    local IP=$1
    VALID_CHECK=$(echo $IP | awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [ $VALID_CHECK == "yes" ]; then
            echo "IP $IP  available!"
            return 0
        else
            echo "IP $IP not available!"
            return 1
        fi
    else
        echo "IP format error!"
        return 1
    fi
}

## 计算子网掩码位数
maskdigits() {
    a=$(echo "$1" | awk -F "." '{print $1" "$2" "$3" "$4}')
    for num in $a; do
        while [ $num != 0 ]; do
            echo -n $(($num % 2)) >>/tmp/num
            num=$(($num / 2))
        done
    done
    echo $(grep -o "1" /tmp/num | wc -l)
    rm /tmp/num
}

### 选择内网网口
echo "请选择内网网卡，选择输入以下网络端口名："
net_name=($(ls /sys/class/net | grep -E 'ens|eth'))
echo ${net_name[*]}

while true; do
    read -p "网卡: " sms_eth_internal
    if [ ! -d /sys/class/net/${sms_eth_internal} ]; then
        echo "输入错误，请重新输入！"
    elif [ -z ${sms_eth_internal} ]; then
        continue
    else
        break
    fi
done

echo "## 内网网卡：" >>env.text
echo "export sms_eth_internal=${sms_eth_internal}" >>env.text
echo "## OS分发网卡：" >>env.text
echo "export eth_provision=${sms_eth_internal}" >>env.text

### 选择内网IP
while true; do
    read -p "输入内网 IP（eg. 10.0.0.1）: " sms_ip
    check_ip $sms_ip
    [ $? -eq 0 ] && break
done

echo "## 内网IP：" >>env.text
echo "export sms_ip=${sms_ip}" >>env.text

echo "## 计算节点NTP时间服务器IP：" >>env.text
echo "export ntp_server=${sms_ip}" >>env.text

### this can be set as a real domain name, such as buildhpc.org###
## so the sms /etc/hosts is as #
#10.0.0.2 cjhpc cjhpc.buildhpc
#10.0.0.201 cnode01 cnode01.build.hpc
###
echo "## 内网子网域名：" >>env.text
echo "export domain_name=local" >>env.text

### 子网掩码设置
while true; do
    read -p "输入子网掩码（eg. 255.255.255.0）: " internal_netmask
    check_ip $internal_netmask
    [ $? -eq 0 ] && break
done
echo "## 内网子网掩码：" >>env.text
echo "export internal_netmask=${internal_netmask}" >>env.text

### 内网子网掩码长度
#while true; do
#    read -p "输入内网子网掩码长度（eg. 24）：" internal_netmask_l
#    if [ $internal_netmask_l -gt 1 ]&&[ $internal_netmask_l -lt 32 ]; then
#        break
#    else
#        echo "输入错误，长度应在1~32之间"
#    fi
#done

internal_netmask_l=$(maskdigits ${internal_netmask})

echo "## 内网子网掩码长度：" >>env.text
echo "export internal_netmask_l=${internal_netmask_l}" >>env.text

echo "## 计算节点名字前缀：" >>env.text
echo "export compute_prefix=cnode" >>env.text
echo "## 计算节点IP网段：" >>env.text
echo "export c_ip_pre=${sms_ip}" >>env.text

### 这里有待改进，后期脚本需要配置IB
echo "## 光网内网IP：" >>env.text
echo "export sms_ipoib=10.0.1.1" >>env.text
echo "## 光网内网掩码：" >>env.text
echo "export ipoib_netmask=255.255.255.0" >>env.text
echo "## 光网内网计算节点IP网段：" >>env.text
echo "export c_ipoib_pre=10.0.1.1" >>env.text

echo "网络参数设置完毕！"

#############example check IP#################
#while true; do
#    read -p "Please enter IP: " IP
#    check_ip $IP
#    [ $? -eq 0 ] && break
#done
