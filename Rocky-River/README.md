# 部署过程和存在的问题

## 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy，并将ventoy写入优盘。<br>
[ventoy 项目地址](https://www.ventoy.net/cn/index.html)
优盘格式可设置为exFAT，便于存放大于4G的文件。
注意，写优盘时设置一个额外的fat分区存放fuse-exfat的rpm安装包，否则安装完系统无法挂载exfat格式优盘。

1. 下载项目所需包，给一个百度盘的地址 <br>
with rocky linux 8.6 提取码 6yju<br>
链接: [https://pan.baidu.com/s/10qIU_qWvAVz3VITdYwD0_w](https://pan.baidu.com/s/10qIU_qWvAVz3VITdYwD0_w?pwd=6yju)
<br>with rocky linux 8.8 提取码 vwym <br>
链接: [https://pan.baidu.com/s/1WtkyZBW6qthjaIrOv3eFdw](https://pan.baidu.com/s/1WtkyZBW6qthjaIrOv3eFdw?pwd=vwym)
可从镜像下载rocky linux 8.8 iso镜像：[下载链接](https://mirror.sjtu.edu.cn/rocky/8.8/isos/x86_64/Rocky-8.8-x86_64-dvd1.iso)

1. 安装Rocky Linux<br>
将所有文件存入优盘，然后从优盘启动并Rocky Linux，安装Rocky Linux

1. 安装fuse-exfat<br>
操作系统安装完成之后
```bash
rpm -i fuse-exfat-1.3.0-3.el8.x86_64.rpm
```
1. 挂载优盘<br>
（可以挂载到/root，/mnt，/media，/run/media的子目录下），类似这样的
```bash
mount /dev/sdb1 /mnt/usb  ###按实际情况修改
```

1. 将Rocky-River文件夹拷贝到 /root 目录，然后<br>
```bash
cp -r /mnt/usb/xxx/Rocky-River /root/   ###按实际情况修改
cd /root/Rocky-River
```
在root目录进行以下操作

1.  执行ini.sh进行初始化设置<br>
```bash
sh ini.sh
```
这里有些交互选项，按要求填写即可。

1. 执行Install.sh进行安装<br>
成功产生 Install.sh之后，执行
```bash
./Install.sh 
```
进行安装。

1.  添加计算节点<br>
- 先查到计算节点的MAC地址，然后写到node_add.list里边，可以写多个MAC(每行一个)
- 运行admin/add_computenode.sh 注册计算节点
- 计算节点从pxe启动，成功获得IP之后会自动安装操作系统和相关软件，首次启动会进行配置，需要等待几分钟时间才能正常登录

1.  添加用户<br>
脚本还没写，用 adduser 添加用户之后，执行 make -C /var/yp 同步用户

## 存在问题
1. 同时多个节点安装时会出现某个节点root无密码登录出错，但是普通用户正常。<br>
目前的办法是对问题节点重新安装。root 授权的机制就是ssh key无密码登录，可能多个虚拟机同时读写虚拟磁盘，磁盘IO拥塞，导致拷贝超时失败。<br>
实际部署估计不会遇到这个问题。


## To do list
- [ ] 统一if后边的括号<br>
if 之后的单括号 与 双括号 的区别，双括号可以避免变量里边的空变量导致判断失败,而双括号是bash才支持的。不过实际上在Centos/Rocky中/bin/sh都执向/bin/bash。所以本项目的 == 和 function 以及 [[]] 都被支持了。所以，应该将if [] 改成 if [[]]。

