### 简要使用说明
项目目前仍在非常初始的阶段，由于本人工作原因，项目前途未卜！
目前项目是可以成功部署的，目前发现的问题是slurm服务开机启动会失效。
项目主要参考openhpc官网的手册，本项目脚本可以供初学者参考学习。
如果觉得本项目对你有帮助，请不要吝惜在GitHub上给我一个Star。
项目地址：
https://github.com/fangjzh/hpc_script

1. 该项目想做一个快速部署的HPC安装程序
2. 该项目被设计成离线安装的模式，能在无网络的环境部署
3. 项目所有文件可以被放在U盘
4. make_distro.sh 包含了离线repo的制作过程


### 简要使用步骤
1. 准备一个32G+的优盘，下载ventoy,将ventoy写入优盘，注意设置一个额外的ext分区存放fuse-exfat程序，否则安装完系统无法挂载优盘
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

### To do list
- [ ] 给项目取个名字，建立一个新的二级目录，repo就不改了
- [ ] 将安装步骤按功能分离
- [ ] 可选组件
- [ ] 学习slurm
- [ ] InfiniBand等硬件
- [ ] BenchMark
- [ ] 服务检测与修复