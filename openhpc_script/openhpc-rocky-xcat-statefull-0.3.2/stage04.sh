#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh
##

## this stage is not finished yet !!! ###

echo this stage is not necessary, we can ommit it....
echo now exit....
exit

filelist=(
n9e-5.7.0.tar.gz 
n9e-fe-5.3.0.tar.gz                    
prometheus-2.28.0.linux-amd64.tar.gz 
telegraf-1.21.4_linux_amd64.tar.gz   
)

for ifile in ${filelist[@]}
do
  if [ ! -e ${package_dir}/nightingleV5/${ifile} ] ; then
  echo "${ifile} is not exist!!!"
  exit
fi
done

##############################
# install prometheus

echo "installing prometheus ...."
echo "webport:9090"

mkdir -p /opt/prometheus
## wget https://s3-gz01.didistatic.com/n9e-pub/prome/prometheus-2.28.0.linux-amd64.tar.gz -O prometheus-2.28.0.linux-amd64.tar.gz
tar xf ${package_dir}/nightingleV5/prometheus-2.28.0.linux-amd64.tar.gz
cp -far prometheus-2.28.0.linux-amd64/*  /opt/prometheus/

# service 
cat <<EOF >/etc/systemd/system/prometheus.service
[Unit]
Description="prometheus"
Documentation=https://prometheus.io/
After=network.target

[Service]
Type=simple

ExecStart=/opt/prometheus/prometheus  --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data --web.enable-lifecycle --enable-feature=remote-write-receiver --query.lookback-delta=2m 

Restart=on-failure
SuccessExitStatus=0
LimitNOFILE=65536
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=prometheus


[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl restart prometheus
systemctl status prometheus



############## about Prometheus Time error #####
## 有时候更改系统时间，导致Prometheus数据库写入错误 ###
## 可以删除数据重来 ##
## systemctl stop prometheus
## rm -rf /opt/prometheus/data/* ##
## systemctl start prometheus


# install mysql
yum -y install mariadb*
systemctl enable mariadb
systemctl restart mariadb
## mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('1234');"

# install redis
yum install -y redis
systemctl enable redis
systemctl restart redis

########## install n9e #######
mkdir -p /opt/n9e && cd /opt/n9e

# 去 https://github.com/didi/nightingale/releases 找最新版本的包，文档里的包地址可能已经不是最新的了
tarball=n9e-5.7.0.tar.gz
# urlpath=https://github.com/didi/nightingale/releases/download/v5.0.0-ga-06/${tarball}
# wget $urlpath || exit 1

tar zxvf ${package_dir}/nightingleV5/${tarball}

mysql -uroot -p'78g*tw23.ysq' < docker/initsql/a-n9e.sql

mysql -uroot -p'78g*tw23.ysq' -e"CREATE USER 'n9e'@'localhost' IDENTIFIED BY 'n9e123456';"
mysql -uroot -p'78g*tw23.ysq' -e"REVOKE ALL PRIVILEGES ON *.* FROM 'n9e'@'localhost';"
mysql -uroot -p'78g*tw23.ysq' -e"GRANT ALL PRIVILEGES ON n9e_v5.* TO 'n9e'@'localhost' IDENTIFIED BY 'n9e123456';"
mysql -uroot -p'78g*tw23.ysq' -e"FLUSH PRIVILEGES"

perl -pi -e "s/User = \"root\"/User = \"n9e\"/" /opt/n9e/etc/server.conf
perl -pi -e "s/Password = \"1234\"/Password = \"n9e123456\"/" /opt/n9e/etc/server.conf

perl -pi -e "s/User = \"root\"/User = \"n9e\"/" /opt/n9e/etc/webapi.conf
perl -pi -e "s/Password = \"1234\"/Password = \"n9e123456\"/" /opt/n9e/etc/webapi.conf

perl -pi -e "s/DEBUG/INFO/" /opt/n9e/etc/server.conf


perl -pi -e "s/\/root\/gopath\/src\/n9e/\/opt\/n9e/" /opt/n9e/etc/service/n9e-server.service
perl -pi -e "s/\/root\/gopath\/src\/n9e/\/opt\/n9e/" /opt/n9e/etc/service/n9e-webapi.service

/bin/cp /opt/n9e/etc/service/n9e-server.service /etc/systemd/system/
/bin/cp /opt/n9e/etc/service/n9e-webapi.service /etc/systemd/system/

perl -ni -e 'print; print"After=network.target mariadb.service prometheus.service\n" if $. == 2' /etc/systemd/system/n9e-server.service
perl -ni -e 'print; print"After=network.target mariadb.service prometheus.service\n" if $. == 2' /etc/systemd/system/n9e-webapi.service
## equal to this
# perl -pi -e 'print"After=network.target prometheus.service\n" if $. == 2' /etc/systemd/system/n9e-server.service
systemctl daemon-reload
systemctl enable n9e-server
systemctl restart n9e-server

### web api
tarball=n9e-fe-5.3.0.tar.gz
# 去 https://github.com/n9e/fe-v5/releases 找最新版本的包，文档里的包地址可能已经不是最新的了
# urlpath=https://github.com/n9e/fe-v5/releases/download/v5.3.0/${tarball}
# wget $urlpath || exit 1
cd /opt/n9e
tar zxvf ${package_dir}/nightingleV5/${tarball}

systemctl enable n9e-webapi
systemctl restart n9e-webapi
##systemctl status n9e-server
######################
echo "web port 18000"
echo "user root password root.2020"

cd /root


## nohup ./n9e server &> server.log &
## nohup ./n9e webapi &> webapi.log &

# check logs
# check port

############# install telegraf #####################
#!/bin/sh

version=1.21.4
tarball=telegraf-${version}_linux_amd64.tar.gz
# wget https://dl.influxdata.com/telegraf/releases/$tarball
tar xzvf ${package_dir}/nightingleV5/$tarball

mkdir -p /opt/ohpc/pub/apps/telegraf
cp -far telegraf-${version}/usr/bin/telegraf /opt/ohpc/pub/apps/telegraf

cat <<EOF > /opt/ohpc/pub/apps/telegraf/telegraf.conf
[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

[[outputs.opentsdb]]
  host = "http://127.0.0.1"
  port = 19000
  http_batch_size = 50
  http_path = "/opentsdb/put"
  debug = false
  separator = "_"

[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = true

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

[[inputs.diskio]]

[[inputs.kernel]]

[[inputs.mem]]

[[inputs.processes]]

[[inputs.system]]
  fielddrop = ["uptime_format"]

[[inputs.net]]
  ignore_protocol_stats = true

EOF

perl -pi -e "s/127.0.0.1/${sms_ip}/" /opt/ohpc/pub/apps/telegraf/telegraf.conf

### 这一段在计算节点上运行即可监控计算节点，注意计算节点要时间同步
cat <<EOF > /etc/systemd/system/telegraf.service
[Unit]
Description="telegraf"
After=network.target

[Service]
Type=simple

ExecStart=/opt/ohpc/pub/apps/telegraf/telegraf --config telegraf.conf
WorkingDirectory=/opt/ohpc/pub/apps/telegraf

SuccessExitStatus=0
LimitNOFILE=65536
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=telegraf
KillMode=process
KillSignal=SIGQUIT
TimeoutStopSec=5
Restart=always


[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable telegraf
systemctl restart telegraf
systemctl status telegraf


################################################################
##  这个在repo里边有，可以直接yum install 到时替换一下
## install grafana-8.1.0-1.x86_64.rpm
filelist=(
grafana-8.1.0-1.x86_64.rpm
)

for ifile in ${filelist[@]}
do
  if [ ! -e ${package_dir}/${ifile} ] ; then
  echo "${ifile} is not exist!!!"
  exit
fi
done

rpm -i ${package_dir}/grafana-8.5.2-1.x86_64.rpm
systemctl daemon-reload
systemctl enable grafana-server.service


echo "ip:localhost port:3000 user and password:admin"
### You can start grafana-server by executing
systemctl start grafana-server.service


echo "======================================================="
echo "boot and wait the compute node install before stage 05!"
echo "======================================================="

######################################################
######################################################
######################################################
######################################################


echo finished.................................

exit


######################################################
######################################################

################################################################
## add prometheus slurm exporter
filelist=(
prometheus-slurm-exporter
)

for ifile in ${filelist[@]}
do
  if [ ! -e ${package_dir}/${ifile} ] ; then
  echo "${ifile} is not exist!!!"
  exit
fi
done

mkdir -p /opt/prometheus/exporters
/bin/cp ${package_dir}/prometheus-slurm-exporter /opt/prometheus/exporters
chmod 555 /opt/prometheus/exporters/prometheus-slurm-exporter

########################
cat <<EOF > /usr/lib/systemd/system/prometheus-slurm-exporter.service
[Unit]
Description=prometheus-slurm-exporter
After=network.target 

[Service]
User=slurm
Group=slurm
ExecStart=/opt/prometheus/exporters/prometheus-slurm-exporter \
          -listen-address=:8082 \
#            -gpus-acct
[Install]
WantedBy=multi-user.target
EOF
#########################
cat <<EOF >> /opt/prometheus/prometheus.yml

#
# SLURM resource manager:
#
  - job_name: 'slurm_expor'

    scrape_interval:  30s
    scrape_timeout:   30s

    static_configs:
      - targets: ['localhost:8082']
EOF

#systemctl daemon-reload
systemctl enable prometheus-slurm-exporter
systemctl start prometheus-slurm-exporter
systemctl restart prometheus

