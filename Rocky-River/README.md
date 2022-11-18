## How to

### 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy,将ventoy写入优盘，注意设置一个额外的fat分区存放fuse-exfat的rpm安装包，否则安装完系统无法挂载优盘
ventoy 项目地址：
https://www.ventoy.net/en/index.html
2. 下载项目所需包，给一个百度盘的地址
链接：xxxxxx

3. 将所有文件存入优盘，然后从优盘启动并安装Rocky Linux

4. 安装完成之后，安装fuse-exfat-1.3.0-3.el8.x86_64.rpm
rpm -i fuse-exfat-1.3.0-3.el8.x86_64.rpm
然后挂载优盘（可以挂载到/root，/mnt，/media，/run/media的子目录下），类似这样的
mount /dev/sdb1 /mnt/usb

5. 将Rocky-River文件夹拷贝到 /root 目录，然后cd /root 在root目录进行操作

6. cd Rocky-River; 执行 sh ini.sh 进行初始化设置

7. 成功产生 Install.sh之后 ./Install.sh 进行安装

8. functions/add_computenode.sh 添加计算节点（待改进）

### To do list
1. if 之后的单括号 与 双括号 的区别，双括号可以避免变量里边的特殊字符导致判断失败
   不知是否需要修改！！！

2. 

