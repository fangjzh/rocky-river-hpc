echo " ## user define " >> /root/.bashrc
echo "unset command_not_found_handle" >> /root/.bashrc
source /root/.bashrc

echo "$0 执行完成！" > $1