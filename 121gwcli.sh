#! /bin/bash
# Start datalogging from 121GW
set -e
# Get the device ID of the first 121GW device found:
DEV=$(bt-device --list | grep 121GW | head -n 1 | sed -e 's/^.*(//' -e 's/).*$//')
if [[ -z $DEV ]]
then
	echo Error: No \'121GW\' device found.
else
	gatttool --device=$DEV --char-write-req -a 0x0009 -n 0300 --listen | $(dirname $(readlink -f $0))/parse121gw.pl $@
	echo \${PIPESTATUS[@]} ${PIPESTATUS[@]}
fi
