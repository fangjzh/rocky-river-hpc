### first install qemu-kvm
参考: [# ubuntu20.04安装KVM虚拟机](https://blog.csdn.net/ymz641/article/details/121563579)
```bash
sudo apt install qemu qemu-kvm libvirt-daemon-system libvirt-clients virt-manager virtinst bridge-utils
```
### then install virtualbmc
```bash
sudo apt-get install gcc libvirt-dev libvirt-clients python3 python3-pip python3-virtualenv 
```

### 切换到管理员
```bash
sudo -i
```
##### then do pip install
```bash
pip install virtualbmc
```

### then install net-tools
```bash
sudo apt-get install net-tools
```

### then add virtual interface
```bash
sudo ifconfig eno2:1 10.0.0.11 up
sudo ifconfig eno2:2 10.0.0.12 up
sudo ifconfig eno2:3 10.0.0.13 up
```

### then add kvms
```bash
echo "need to do...."
echo "need to do...."
echo "need to do...."
```
显示网卡MAC
```bash
virsh list
virsh domiflist cnode01
```

### then add machines in vbmc
参考：[virtualbmc的使用](https://ironic-book.readthedocs.io/zh_CN/latest/ironic/vbmc.html)
#### start vbmcd
```bash
vbmcd
```
do it with root, so U can use 623 port
if user is nort root need to specify --port <6230|6231>
then xcat shoud be cracked with IPMI port table
```bash
vbmc add cnode01 --address 10.0.0.11
vbmc add cnode02 --address 10.0.0.12
vbmc add cnode03 --address 10.0.0.13
vbmc start cnode01 cnode02 cnode03
```
### add a start script to stat vmcd
```bash
cat <<EOF > /root/start_vbmc.sh
echo "" > ~/.vbmc/master.pid
sudo ifconfig eno2:1 10.0.0.11 up
sudo ifconfig eno2:2 10.0.0.12 up
sudo ifconfig eno2:3 10.0.0.13 up
vbmcd
EOF
```

### then in xCAT-HPC

```bash
##echo if with IPMI port
##/bin/cp xcat_2.16.4_crack_vbmc/xCAT/*.pm /opt/xcat/lib/perl/xCAT
##/bin/cp xcat_2.16.4_crack_vbmc/xCAT_plugin/*.pm /opt/xcat/lib/perl/xCAT_plugin
##systemctl restart xcatd
######## add ipmi support ######
nodech compute nodehm.power=ipmi nodehm.mgt=ipmi
```

#### add ipmi settings for node
```bash
### echo if ipmi port is specified !!!
##nodech cnode02 ipmi.bmc=10.0.0.3 ipmi.port=6230  ipmi.username=admin ipmi.password=password
##lsdef -t node cnode02
nodech cnode01 ipmi.bmc=10.0.0.2 ipmi.username=admin ipmi.password=password
```