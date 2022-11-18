#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 用户自定义设置 - - - - - - - -"
echo "$0 执行开始！" >${0##*/}.log

echo " ## user define " >>/root/.bashrc
echo "unset command_not_found_handle" >>/root/.bashrc
source /root/.bashrc

echo "-->执行 $0 : 用户自定义设置完成 + = + = + = + = + ="

echo "$0 执行完成！" >>${0##*/}.log
