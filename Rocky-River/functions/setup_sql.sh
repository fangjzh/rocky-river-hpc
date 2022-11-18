#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置数据库软件 - - - - - - - -"

### install sql
yum -y -q install mariadb*
# 假设机器的/home分区是个SSD的大分区，datadir设置为/home/mysql
# mkdir -p /home/mysql
# chown mysql:mysql /home/mysql
# sed -i '/^datadir/s/^.*$/datadir=\/home\/mysql/g' /etc/my.cnf
# 启动mysql进程
systemctl start mariadb.service
# 将mysql设置为开机自启动
systemctl enable mariadb.service
# 设置mysql root密码
mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('78g*tw23.ysq');"

echo "-->执行 $0 : 安装设置数据库软件完毕 + = + = + = + = + ="

echo "$0 执行完成！" >${0##*/}.log
