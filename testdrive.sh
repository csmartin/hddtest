#!/bin/bash
# Author: Carl Martin <cmartin@nexcess.net>
# Tests a drive with badblocks and creates a log of it. Sends summary email on completion.
# Usage:
#    testdrive.sh sdf email@address.com


thedate=$(date +%Y-%m-%d-%H%M)
log_file=logs/badblocks-$1-$thedate.log

if [ "$1" = "sda" ]
then
    echo "/dev/sda may not be tested, since the OS is on this drive. Try again."
    exit
fi

echo "Testing drive /dev/$1" | tee $log_file   # no -a here, to create a new file
echo "Starting at $(date +%Y-%m-%d-%H:%M:%S)" | tee -a $log_file

# Retrieve serial number - compatible with both SAS and SATA
serialnum=$(/usr/local/bin/sdparm --page=SN /dev/$1  | tail -1 | awk '{print $1}')

# Determine SATA or SAS for other variables
is_ata=$(/usr/local/bin/sdparm /dev/$1 | awk '{print $2}' | head -1)
echo "is_ata: $is_ata"
if [ $is_ata = "ATA" ]
then
    echo "Drive is SATA" | tee -a $log_file
    manuf=$(hdparm -I /dev/$1 | grep "Model Number" | awk '{print $3}')
    modelnum=$(hdparm -I /dev/$1 | grep "Model Number" | awk '{print $4}')
    prestat=$(/usr/local/sbin/smartctl -T permissive  -a /dev/$1 | egrep "(Realloc|Current_Pe|Offline_Unc)")
else
    echo "Drive is SAS" | tee -a $log_file
    manuf=$(/usr/local/bin/sdparm /dev/$1 | awk '{print $2}' | head -1)
    modelnum=$is_ata
    prestat=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | egrep "(Non-medium|grown defect)")
fi

echo "Manufacturer: $manuf" | tee -a $log_file
echo "Model: $modelnum" | tee -a $log_file
echo "Serial: $serialnum" | tee -a $log_file

devsize=$(fdisk -l /dev/$1 2>/dev/null | head -2 | tail -1 | awk '{print $3,$4}' | sed s/,//)
echo "Size: $devsize" | tee -a $log_file


#show pre-test stats
echo "Pre-test stats:" | tee -a $log_file
echo "$prestat" | tee -a $log_file

#check smart before the test
if [ $is_ata = "ATA" ]
then
    presmartline=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | grep "SMART overall-health")
else
    presmartline=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | grep "SMART Health Status")
fi
echo "$presmartline" | tee -a $log_file

#run the test
bbcount=$(badblocks -swft random /dev/$1 | tee -a $log_file | wc -l)

if [ "$bbcount" != "0" ]
then
    echo "**** NON-ZERO BAD BLOCK COUNT ****"
fi

#check smart after the test
if [ $is_ata = "ATA" ]
then
    smartline=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | grep "SMART overall-health")
else
    smartline=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | grep "SMART Health Status")
fi

echo "$bbcount bad block(s) found." | tee -a $log_file # echo to screen and log
echo "$smartline" | tee -a $log_file # echo to screen and log

echo "Finished at $(date +%Y-%m-%d-%H:%M:%S)." | tee -a $log_file;

#show post-test stats
if [ $is_ata = "ATA" ]
then
    poststat=$(/usr/local/sbin/smartctl -T permissive  -a /dev/$1 | egrep "(Realloc|Current_Pe|Offline_Unc)")
else
    poststat=$(/usr/local/sbin/smartctl -T permissive -a /dev/$1 | egrep "(Non-medium|grown defect)")
fi

echo "Post-test stats:" | tee -a $log_file
echo "$poststat" | tee -a $log_file
