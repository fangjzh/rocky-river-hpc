## 本目录仅做脚本参考备份，代码已经迁移到 Rocky-River文件夹下

### 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy,将ventoy写入优盘，注意设置一个额外的fat分区存放fuse-exfat的rpm安装包，否则安装完系统无法挂载优盘
ventoy 项目地址：
https://www.ventoy.net/en/index.html
2. 下载项目所需包，给一个百度盘的地址
链接：https://pan.baidu.com/s/1NpL-YjwgVy3gp1vUD5j_MQ?pwd=2022 

3. 将所有文件存入优盘，然后从优盘启动并安装Rocky Linux

4. 安装完成之后，安装fuse-exfat-1.3.0-3.el8.x86_64.rpm
rpm -i fuse-exfat-1.3.0-3.el8.x86_64.rpm
然后挂载优盘，类似这样的
mount /dev/sdb1 /mnt/usb

4. 安装完成后，进入openhpc-rocky-xcat-statefull-xxx，更改env.sh里的内容
主要是 安装所需文件的位置和网卡名字
export base_dir=/mnt/usb1    ## 安装包所在位置
export package_dir=${base_dir}/OHPC
export iso_path=${base_dir}/OS   ## 系统镜像所在位置
使用ip a查看网卡名字，然后做相应更改
export sms_eth_internal=ens34

5. 接着就可以执行 
sh stage00.sh

sh stage01.sh

sh stage02.sh

sh stage03.sh  ## 这个是添加计算节点的脚本

stage04.sh 添加了监控软件，这个不在软件包里
stage05.sh 做了计算节点的一些设置
stage06.sh 安装了额外的编译器等

  未完待续！！！！