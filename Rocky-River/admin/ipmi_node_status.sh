#!/bin/bash
echo -e "HeadNode:"
ipmitool -I lanplus -H 192.168.5.200 -U admin -P xxxxxxx power status
echo -e "CNode001:"
ipmitool -I lanplus -H 192.168.5.201 -U admin -P xxxxxxx power status
