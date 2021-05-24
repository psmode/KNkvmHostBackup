#!/bin/sh
#
#
SLEEP_INTERVAL="10"
MAX_WAIT_LOOPS=10
#
TARGET="$1"
#
#
echo "***"
echo "***"
echo "*** `date +%x\ %T`: Find target VM for $TARGET"
echo "***"
	UV=""
	if [ "$TARGET" != "" ]
	then
	   UV=$(virsh list --all --title | awk -- '/'" $TARGET "'/ {print $2; exit}')
	fi

	if [ "$UV" == "" ]
	then
	   echo "** Error: Could not find VM for $TARGET - exiting on error **"
	   exit 2
	else
	   UV_STATE1=$(virsh domstate $UV)
           echo "Current state of VM $UV ($TARGET): $UV_STATE1"
	   echo ""
	fi

echo "***"
echo "***"
echo "*** `date +%x\ %T`: Shutdown VM $UV ($TARGET)"
echo "***"
	if [ "$UV_STATE1" == "running" ]
	then
	   echo "Shutting down running VM $UV ($TARGET)"
	   virsh shutdown $UV
	else
	   echo " ** Warning: VM $UV ($TARGET) current state is $UV_STATE1 - skipping shutdown"
	fi
	echo ""

echo "***"
echo "***"
echo "*** `date +%x\ %T`: Wait for shutdown of VM $UV ($TARGET)"
echo "***"
	loop_count=0
	UV_STATE=$(virsh domstate $UV)
	while [ "$UV_STATE" == "running" ] && [[ $loop_count -lt $MAX_WAIT_LOOPS ]]
	do
	   echo "- `date +%x\ %T`: Current state is $UV_STATE - sleep $SLEEP_INTERVAL"
	   loop_count=$((loop_count+1))
	   sleep $SLEEP_INTERVAL
	   UV_STATE=$(virsh domstate $UV)
	done
	if [ "$UV_STATE" == "running" ]
	then
	   echo "** Error: VM $UV ($TARGET) did not shutdown - exiting on error **"
	   exit 2	   
	else
	   echo "- `date +%x\ %T`: Current state is $UV_STATE - wait complete"
	   echo ""
	fi 

echo "***"
echo "***"
echo "*** `date +%x\ %T`: Snap LVs for VM $UV ($TARGET)"
echo "***"
	/sbin/lvs | grep "LSize\|$UV-"
	echo ""
	# lvcreate  --extents 50%ORIGIN --snapshot --name bu-uv018-disk0 /dev/T0/uv018-disk0
	# lvremove --force --verbose /dev/T0/bu-uv018-disk0
	eval $(/sbin/lvs --units=m  --noheadings --nosuffix | awk -- "/$UV-.*/ {printf(\"/sbin/lvcreate --extents 50%ORIGIN --snapshot --name bu-%s /dev/%s/%s;\\n/sbin/lvdisplay %s/%s;\\n\", \$1, \$2, \$1, \$2, \$1)}")
	/sbin/lvs --verbose | grep "UUID\|$UV"
	echo ""

echo "***"
echo "***"
echo "*** `date +%x\ %T`: Restart VM $UV ($TARGET) if previously running"
echo "***"
        if [ "$UV_STATE1" == "running" ]
        then
	   echo "Restart VM $UV ($TARGET)"
	   virsh start $UV
        else
	   echo " ** Warning: VM $UV ($TARGET) previous state was $UV_STATE1 - skipping startup **"
        fi
	echo ""

	export UV
	export TARGET
