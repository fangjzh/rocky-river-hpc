#!/bin/bash

echo 'useage ./create_ca.sh $mydomain'
 
domain=*.test.com
if [ -n "$1" ];then
    domain=$1
fi
 
client_ip=192.168.1.2
 
# 生成文件目标路径
current_path=$(cd "$(dirname $0)";pwd)
 
dir=$current_path/output/
 
if [ ! -d $dir ]; then
  sudo mkdir -p -m 755 $dir
  echo "sudo mkdir -p -m 755 ${dir} done"
fi
 
# 生成自签名的CA key和证书(简单起见客户端和服务端共用一个CA证书)
sudo openssl genrsa -out $dir/ca.key 2048
sudo openssl req -x509 -new -nodes -key $dir/ca.key -sha256 -days 3650 -subj "/CN=$domain" -out $dir/ca.pem
  
# 生成服务器端的key和证书
sudo openssl genrsa -out $dir/server.key 2048
sudo openssl req -new -key $dir/server.key -out $dir/server.csr -subj "/CN=127.0.0.1"
sudo openssl x509 -req -in $dir/server.csr -CA $dir/ca.pem -CAkey $dir/ca.key -CAcreateserial -out $dir/server.pem -days 3650 -sha256
  
  
# 生成客户端key和证书
sudo openssl genrsa -out $dir/client.key 2048
sudo openssl req -new -key $dir/client.key -out $dir/client.csr -subj "/CN=$client_ip"
sudo openssl x509 -req -in $dir/client.csr -CA $dir/ca.pem -CAkey $dir/ca.key -CAcreateserial -out $dir/client.pem -days 3650 -sha256
  
  
# PKCS1私钥转换为PKCS8(该格式java调用)
sudo openssl pkcs8 -topk8 -inform PEM -in $dir/client.key -outform pem -nocrypt -out $dir/pkcs8.pem
