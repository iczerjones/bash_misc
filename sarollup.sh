#!/usr/bin/bash
# Concatenates sar logs in chronological order to create
# a one month record. Also gathers core logs and hardware
# information
#
# cnietzold@scalecomputing.com


# set finished file suffix
descriptor=`hostname`

# cleanup all arrays and temp directory
cleanup(){
	sync; rm -rf ${tdir}/*; rm -rf ${tdir}
	unset sars; unset last; unset part; sync
}

# take argument for sar file location, or check for common
# location in /var/log/sa/sar* and set as location if found
location=$1
if [ $# -eq 0 ]; then
	if [ `ls /var/log/sa/sar* | wc -l` -gt 2 ]; then
		location="/var/log/sa"
	else
		echo "usage: ./sarollup.sh [PATH] "; sleep 1
		exit 1
	fi
fi

# remove trailing / if present
if [[ `echo ${location: -1}` == "/" ]]; then
	location=${location%/}
fi

# set todays day of the month as a reference then note the
# highest recorded value
now=`date +%d`
if [ `ls ${location}/sar* | grep converted | wc -l` -gt 0 ]; then
	rm -f ${location}/*converted; sync
fi
last=$(ls ${location}/sar* | wc -l)

# build an array ordered by day of the month using today
# as the reference point. Since sar logs are generally 1 day
# behind, start with today + 1, unless today is 1, then 
# iterate through the entirety of last month, start to finish
if [ $now -eq 1 ]; then
	sars=( $(seq 1 $last) )
else
	sars=( $(seq $(echo "$now + 1" | bc) $last ) )
	sars+=( $(seq 1 $now) )
fi

# set a file to write out to using $descriptor as suffix;
# create temp directory for storing log files
tdir="/tmp/supportbundle"
mkdir $tdir; sync
target="${tdir}/sarfile_${descriptor}"

# append each day's logs in chronological order
for part in ${sars[@]}; do
	if [ ${#part} -eq 1 ]; then
		part="0${part}"
	fi
	cat ${location}/sar${part} >> $target
done

# gather ethtool info
ethtool -i lan0 > ${tdir}/eth_info-${descriptor}
echo "-------------------------" >> ${tdir}/eth_info-${descriptor}
ethtool -d lan0 >> ${tdir}/eth_info-${descriptor}
echo "-------------------------" >> ${tdir}/eth_info-${descriptor}
ethtool lan0 >> ${tdir}/eth_info-${descriptor}

# gather smartctl drive info
smartctl -a /dev/nvme0n1 > ${tdir}/nvme_info-${descriptor}

# gather dmidecode info
dmidecode > ${tdir}/dmi_info-${descriptor}

# gather dmesg and scale logs
tar czf ${tdir}/messages-${descriptor} /var/log/messages* &>/dev/null
tar czf ${tdir}/scalelogs-${descriptor}.tar.gz /var/log/scale/* &>/dev/null

# create single bundle and clean up
sync; tar czf supportbundle-${descriptor} ${tdir}/*
echo "All done.  ;) "; sleep 2; exit 0
