# 项目名称
中文名：岩川 <br>
英文名：Rocky River 
# 项目许可
This project is licensed under the MIT License - see the LICENSE file for details.

# 项目地址:
[Rocky River HPC github page](https://github.com/fangjzh/rocky-river-hpc)

# 项目logo
![logo](https://github.com/fangjzh/rocky-river-hpc/blob/master/Rocky-River/HPClogo/logo_r.png "Rocky River Logo")

# 项目简介
Rocky River HPC Toolkit 是一个基于OpenHPC和XCAT的HPC集群搭建和管理工具，提供集群节点管理、任务调度、多用户多任务管理、集群监控、集群管理等服务。

# 开发说明
本项目旨在减轻初创科研团队HPC集群搭建和运维的困难。初创科研团队由于资金和硬件供应商技术缺乏等因素，需要额外的HPC运维技术支持。此项目可轻松地完成小规模HPC集群搭建，从学习的角度亦可促进HPC技术人才的培养。
项目的原始出发点来自本人在博士期间的HPC运维经历，该项目一方面是对多年HPC运维经验的总结，另一方面是为资金不宽裕的科研工作者在集群搭建方面提供些许帮助。为了节约开发和部署时间，项目有以下考虑：
- 首先注重基础功能，即集群节点互联与统一管理、并行开发和运行环境、多用户多任务调度等，对于非主要功能可在开发和部署中适当削减。
- 为开发方便，项目基于openhpc和xcat两个上游项目，操作系统首先之确定单个操作系统，即Rocky Linux。
- 考虑到实际部署时的机房条件问题，项目将所有需要的文件打包，包括操作系统，最终发行版可以放在一个优盘里，无需互联网可部署。
- 考虑到版本更新，将发行版的制作过程也写成脚本。

## 项目情况说明
1. 项目目前完成了基础功能，已有功能经过虚拟机反复测试，并完成多次单机和集群部署，形成生产力。
2. 项目的功能代码放在Rocky-River 目录下，该目录下包含简要步骤。
3. 项目主要参考openhpc官网的手册，本项目脚本可以供初学者参考学习。
4. 由于本人工作原因，鸽的时间比较长，有问题可mail : fangjzh#foxmail.com 。防止抓取，'#'改成'@'！
5. 项目的开发受到了HPC技术交流群（130653201）中各位大佬的支持和启发，如果觉得本项目对你有帮助，请慷慨地点击Star。


## 操作步骤与已有功能
### 步骤：
- 参考 Rocky-River 目录下的 [README.md](https://github.com/fangjzh/rocky-river-hpc/blob/master/Rocky-River/README.md)
- 参考视频：https://www.bilibili.com/video/BV1Do4y1j7qg


### 功能：
1. 一枚优盘离线快速安装所有功能
2. 包含编译环境，GNU compiler和Intel OneAPI, mpi编译库和运行库
3. module 载入环境变量
4. 计算节点批量部署与管理功能
5. slurm调度器基本配置，包含数据库记账功能
6. 初步的集群监控支持

### To do list
- [ ] 自定义共享目录
- [ ] 完善用户添加脚本
- [ ] 自定义数据库密码，这个有点重要！！
- [ ] 各项服务的检测与修复脚本
- [ ] 提供slurm基本使用手册，用户限额配置，GPU调度等
- [ ] InfiniBand等硬件的支持
- [ ] 磁盘配额等配置
- [ ] 写开发和使用手册
- [ ] 非核心功能作为可选组件
- [ ] Grafana+Echarts制作自定义看板
- [ ] BenchMark简单性能评估脚本
- [ ] 完善集群监控和告警功能

### Done!
- [x] 单脚本初始化安装程序，通过交互设置参数
- [x] 将安装步骤按功能分离，一级功能分为部署脚本和维护脚本
- [x] 原始logo设计，一座山下流过一条河
- [x] 决定了，名字叫“岩川”，英文名叫Rocky River。
- [x] 给项目取个名字，建立一个新的二级目录
- [x] 得整一个license

### bug
- [ ] addnode部分，数量超过8和就有问题。似乎是数量函数哪里有点格式问题
