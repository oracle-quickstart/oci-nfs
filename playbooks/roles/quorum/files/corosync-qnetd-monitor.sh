#!/bin/bash

pcount=`ps -efw | grep "[c]orosync-qnetd"|awk '{print $1}'|grep coroqne | wc -l` ;
if [ $pcount -eq 1 ]; then
  echo "process already running"
else
  echo "corosync-qnetd service is not running, restart it"
  systemctl start  corosync-qnetd
fi
