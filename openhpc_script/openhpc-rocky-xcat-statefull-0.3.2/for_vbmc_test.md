### first install qemu-kvm 
##!! ref: https://blog.csdn.net/ymz641/article/details/121563579
sudo apt install qemu qemu-kvm libvirt-daemon-system libvirt-clients virt-manager virtinst bridge-utils
### then install virtualbmc
sudo apt-get install gcc libvirt-dev libvirt-clients python3 python3-pip python3-virtualenv  
sudo -i
##### then do pip install
pip install virtualbmc
##!!##

### then install net-tools
sudo apt-get install net-tools
### then add virtual interface
sudo ifconfig eno2:1 10.0.0.11 up
sudo ifconfig eno2:2 10.0.0.12 up
sudo ifconfig eno2:3 10.0.0.13 up

### then add kvms
echo "need to do...."
virsh domiflist cnode01

### then add machines in vbmc
#### start vbmcd
vbmcd
##!! do it with root, so u can use 623 port
##!! if user is nort root need to specify --port <6230|6231>
##!! then xcat shoud be cracked with IPMI port table
vbmc add cnode01 --address 10.0.0.11 
vbmc add cnode02 --address 10.0.0.12
vbmc add cnode03 --address 10.0.0.13

vbmc start cnode01 cnode02 cnode03

### add a start script to stat vmcd 
echo "" > ~/.vbmc/master.pid
sudo ifconfig eno2:1 10.0.0.11 up
sudo ifconfig eno2:2 10.0.0.12 up
sudo ifconfig eno2:3 10.0.0.13 up
vbmcd

### then in xCAT-HPC

##!! echo if with IPMI port
##!! /bin/cp xcat_2.16.4_crack_vbmc/xCAT/*.pm /opt/xcat/lib/perl/xCAT
##!! /bin/cp xcat_2.16.4_crack_vbmc/xCAT_plugin/*.pm /opt/xcat/lib/perl/xCAT_plugin
##!! systemctl restart xcatd
########!! add ipmi support ######
##!! nodech compute nodehm.power=ipmi nodehm.mgt=ipmi
##!! nodech cnode02 ipmi.bmc=10.0.0.3 ipmi.port=6230  ipmi.username=admin ipmi.password=password
##!! lsdef -t node cnode02

#### add ipmi settings for node
nodech cnode01 ipmi.bmc=10.0.0.2 ipmi.username=admin ipmi.password=password

