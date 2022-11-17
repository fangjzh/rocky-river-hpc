#!/bin/bash

err_v=1

while [ $err_v -eq 1 ] 
do
    echo "请输入集群名字，4-10个英文字符："
    read cname

## 检查非法字符
    for ((i=1;i<=${#cname};i++)); do
        tname=${cname:$i-1:1}
        case "$tname" in
            [a-z]|[A-Z]) ;;
            [0-9]) ;;
            "_") ;;
            "-") ;;
            *)
            echo "包含非法字符！"
            err_v=1
            continue 2;; ## 继续第2层循环
        esac
    done

## 检查是否字母开头  
    if [ `echo $cname | grep ^[a-zA-Z]` ] ; then
        err_v=0 
    else
        err_v=1
        echo "必须以字母开头！"
        continue
    fi
  
## 检查字符串长度 
    if [ ${#cname} -lt 4 ] ; then
        echo "长度必须大于等于4！"
        err_v=1
        continue
    elif [ ${#cname} -gt 10 ] ; then
        echo "长度必须小于等于10！"
        err_v=1
        continue
    fi

done

if [ $err_v -eq 0 ] ; then
    echo "你的集群名为："$cname
    echo "## 集群名：" >> env.text
    echo "export sms_name=$cname" >> env.text
fi
