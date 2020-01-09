#!/bin/bash

#simple script to change unRAID versions

if [ -z "$1" ]
then
      echo "Usage: ./change_versions.sh [VERSION NUMBER]"
      exit 0
fi

echo "checking if version $1 is available for download..."

  if [[ `wget -S --spider https://s3.amazonaws.com/dnld.lime-technology.com/stable/unRAIDServer-$1-x86_64.zip  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then 
    echo ""
    echo "Version found.. downloading"
    echo ""
    mkdir /root/temp
    cd /root/temp
    wget https://s3.amazonaws.com/dnld.lime-technology.com/stable/unRAIDServer-$1-x86_64.zip
    unzip unRAIDServer-$1-x86_64.zip
    cp bz* /boot/
    rm -rf /root/temp
    sleep 2
    echo ""
    echo "** REBOOTING **"
    echo ""
    reboot
  else
    echo "version $1 not available for download"
  fi
