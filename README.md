### 开发说明
1. 项目目前完成了基础功能，经过了虚拟机反复测试，并在某学校完成了单机部署，形成生产力。
2. 项目的功能代码放在Rocky-River 目录下，该目录下包含简要步骤。
3. 项目主要参考openhpc官网的手册，本项目脚本可以供初学者参考学习。
4. 由于本人工作原因，鸽的时间比较长，有问题可mail : fangjzh#foxmail.com 。防止抓取，'#'改成'@'！
5. 如果觉得本项目对你有帮助，请不要吝惜在GitHub上给我一个Star。

[项目地址：](https://github.com/fangjzh/rocky-river-hpc)

### 开发想法与目标
  博士期间为课题组和学院提供了多年的HPC运维支持，从前用集成套件Rocks, 但是我探索到版本7, 感觉问题太多了，部署出现问题不容易解决，同时更新很慢甚至大概率不会有下个版本了。为了（利用闲暇时间）更快更好的完成一些基础HPC搭建和运维服务，在“对角线”等人的启发下，开始了这个项目。
  项目主要的时间可能花费在测试上，有了整体的概念之后，搭建和管理集群不是件很难的事情，不过实际部署还是可能遇到硬件方面的问题。
  该项目的开发过程中，向上游的XCAT项目贡献了Rocky Linux操作系统的支持，选择Rocky Linux也是多方考虑的，其中包括OpenHPC套件的支持考虑。
1. 该项目想做一个快速部署的HPC安装程序，初期的想法是（或有偿^_^）支持同门师兄弟姐妹的工作，希望有其他人来参与开发这个项目，但目前没有。
2. 该项目被设计成离线安装的模式，能在无网络的环境部署(类似Rocks Cluster)
3. 项目所有文件可以被放在U盘
4. 项目包含离线repo的制作脚本，方便版本更新
5. 基础功能大概率会一直公开，可能会有一些个性化收费的项目，当然赚￥很难的。
6. 操作系统目前仅支持Rocky Linux，其他操作系统下的部署暂未开发，其他操作系统支持未来可能有但收费。

### 操作步骤与已有功能
步骤：参考 Rocky-River 目录下的 README.md
功能：
1. 一枚优盘离线快速安装所有功能
2. 包含编译环境，GNU compiler和Intel OneAPI, mpi编译库和运行库
3. moudule 载入环境变量
4. 计算节点批量部署与管理功能
5. slurm调度器基本配置，包含数据库记账功能

### To do list
- [ ] 可选组件
- [ ] 学习slurm，提供slurm基本使用手册，用户限额配置，GPU调度等
- [ ] InfiniBand等硬件
- [ ] BenchMark
- [ ] 服务检测与修复
- [ ] 写文档
- [ ] Grafana+Echarts制作自定义看板
- [ ] 上线基本的集群监考和告警功能
- [ ] 磁盘配额等配置


### Done!
- [X] 将安装步骤按功能分离
- [x] 决定了，名字叫“岩川”，英文名叫Rocky River。
- [x] 新建一个文件夹叫做Rocky-River.
- [x] 给项目取个名字，建立一个新的二级目录