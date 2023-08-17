# 部署过程和存在的问题

## 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy，并将ventoy写入优盘。<br>
[ventoy 项目地址](https://www.ventoy.net/cn/index.html)
优盘格式可设置为exFAT，便于存放大于4G的文件。
注意，写优盘时设置一个额外的fat分区存放fuse-exfat的rpm安装包，否则安装完系统无法挂载exfat格式优盘。

2. 下载项目所需包，给一个百度盘的地址 <br>
<br>**最新版本：**<br>
with rocky linux 8.8 提取码 dzr6<br>
链接: [https://pan.baidu.com/s/1c_eXUCx54zQFk5Vzi_q_0Q](https://pan.baidu.com/s/1c_eXUCx54zQFk5Vzi_q_0Q?pwd=dzr6)

注：其中的Rocky Linux系统镜像是从官网直接下的，可从其镜像站下载rocky linux 8.8 iso：[下载链接](https://mirror.sjtu.edu.cn/rocky/8.8/isos/x86_64/Rocky-8.8-x86_64-dvd1.iso)

**往期版本：**
<br>with rocky linux 8.6 提取码 l8ya <br>
链接: [https://pan.baidu.com/s/1h3flpNhD48oNdN8cjgETrQ](https://pan.baidu.com/s/1h3flpNhD48oNdN8cjgETrQ?pwd=l8ya)


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
- 先查到计算节点的MAC地址，然后写到node_add.list里边，可以写多个MAC(每行一个)
- 运行admin/add_computenode.sh 注册计算节点
- 计算节点从pxe启动，成功获得IP之后会自动安装操作系统和相关软件，首次启动会进行配置，需要等待几分钟时间才能正常登录
- 计算节点完成安装之后，需要执行admin/after_add_computenode.sh 将munge key拷贝到计算节点

10. 修改slurm配置文件
修改 /etc/slurm/slurm.conf，主要是修改节点核数，根据实际情况修改，比如：<br>
NodeName=cnode00[1-3] Sockets=2 CoresPerSocket=32 ThreadsPerCore=1 State=UNKNOWN
意思是这些节点都具有两块CPU，每块CPU有32个物理核心，每个物理核心允许单个线程。
完成之后需要重启slurmctld服务。

11.  添加用户<br>
脚本还没写，用 adduser 添加用户之后，执行 make -C /var/yp 同步用户

## 存在问题
1. 同时多个节点安装时会出现某个节点root无密码登录出错，但是普通用户正常。<br>
目前的办法是对问题节点重新安装。root 授权的机制就是ssh key无密码登录，可能多个虚拟机同时读写虚拟磁盘，磁盘IO拥塞，导致拷贝超时失败。<br>
实际部署估计不会遇到这个问题。
2. 设置计算节点内网时，要避免和企业/校园内网网段重叠，否则会产生不可预料的问题，比如无法上网，无法拨号，无法ssh连接等

## 常用操作
1. slurm 服务相关<br>
- slurm的服务端（管理节点）需要启动的服务 slurmdbd slurmctld
- slurm客户端（承担计算任务的节点）需要启动的服务 slurmd munge <br>
用sinfo查看机器状态如果出现联系不到服务器之类的提示，说明相关服务没启动，需要用
`systemctl status xxx`
命令去查看这些服务的状态，如果所有服务状态都正常，则可以在头节点用
`scontrol update nodename=all state=idle`
刷新节点状态



## To do list
- [ ] 统一if后边的括号<br>
if 之后的单括号 与 双括号 的区别，双括号可以避免变量里边的空变量导致判断失败,而双括号是bash才支持的。不过实际上在Centos/Rocky中/bin/sh都执向/bin/bash。所以本项目的 == 和 function 以及 [[]] 都被支持了。所以，应该将if [] 改成 if [[]]。

