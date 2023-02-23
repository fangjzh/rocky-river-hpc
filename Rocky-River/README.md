# 部署过程和存在的问题

## 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy，并将ventoy写入优盘。<br>
[ventoy 项目地址](https://www.ventoy.net/cn/index.html)
优盘格式可设置为exFAT，便于存放大于4G的文件。
注意，写优盘时设置一个额外的fat分区存放fuse-exfat的rpm安装包，否则安装完系统无法挂载exfat格式优盘。

2. 下载项目所需包，给一个百度盘的地址<br>
链接: [https://pan.baidu.com/s/10qIU_qWvAVz3VITdYwD0_w](https://pan.baidu.com/s/10qIU_qWvAVz3VITdYwD0_w?pwd=6yju)

3. 安装Rocky Linux<br>
将所有文件存入优盘，然后从优盘启动并Rocky Linux，安装Rocky Linux

4. 安装fuse-exfat<br>
操作系统安装完成之后
```bash
rpm -i fuse-exfat-1.3.0-3.el8.x86_64.rpm
```
5. 挂载优盘<br>
（可以挂载到/root，/mnt，/media，/run/media的子目录下），类似这样的
```bash
mount /dev/sdb1 /mnt/usb  ###按实际情况修改
```

6. 将Rocky-River文件夹拷贝到 /root 目录，然后<br>
```bash
cp -r /mnt/usb/xxx/Rocky-River /root/   ###按实际情况修改
cd /root/Rocky-River
```
在root目录进行以下操作

7.  执行ini.sh进行初始化设置<br>
```bash
sh ini.sh
```
这里有些交互选项，按要求填写即可。

8. 执行Install.sh进行安装<br>
成功产生 Install.sh之后，执行
```bash
./Install.sh 
```
进行安装。

9.  添加计算节点<br>
运行functions/add_computenode.sh添加计算节点（待改进）

## 存在问题
1. 同时多个节点安装时会出现某个节点root无密码登录出错，但是普通用户正常。<br>
目前的办法是对问题节点重新安装。root 授权的机制就是ssh key无密码登录，可能多个虚拟机同事读写文件忙，导致拷贝超时失败。


## To do list
- [ ] 统一if后边的括号<br>
if 之后的单括号 与 双括号 的区别，双括号可以避免变量里边的空变量导致判断失败,而双括号是bash才支持的。不过实际上在Centos/Rocky中/bin/sh都执向/bin/bash。所以本项目的 == 和 function 以及 [[]] 都被支持了。所以，应该将if [] 改成 if [[]]。

