#!/bin/bash


count=`ps -ef | grep jormungandr | wc -l`
echo $count

if [ $count -lt 2 ];
then
  /usr/bin/nohup /root/jormungandr --genesis-block-hash $(cat /root/genesis-hash.txt) --config /root/node-config.yaml --secret /root/node-secret.yaml --log-level info &
fi
