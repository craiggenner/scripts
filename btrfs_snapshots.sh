#!/bin/bash

BASE="/storage"
KEEP=4
DATE=`date +%F_%X`
WEEKSAGO=`date -d "${KEEP} weeks ago" +%s`

# Loop through each of the btrfs file systems
for FS in ${BASE}
do
	# Create the default snapshot
	btrfs subvolume snapshot ${FS}/ ${FS}/backup/snapshots/${DATE}

	# For each subvolume that isn't a snapshot
	for SUBVOL in `btrfs subvolume list ${FS} | awk '!/backup\/snapshots/ {print $7}'`
	do
		# if the current subvolume has a path in it
		if [ `echo ${SUBVOL} | grep "/"` ]
		then
			# if the parent directory doesn't exist then create it
			[[ -d "${FS}/backup/snapshots/${DATE}_`dirname ${SUBVOL}`" ]] || mkdir -p ${FS}/backup/snapshots/${DATE}_`dirname ${SUBVOL}`
		fi
		# Create the snapshot with the date and subvolume path
		btrfs subvolume snapshot ${FS}/$SUBVOL ${FS}/backup/snapshots/${DATE}_$SUBVOL
	done

	# Get a list of snapshot dates
	for SUBVOL in `ls -1 ${FS}/backup/snapshots | grep "20[0-9]\{2\}-[0-1][0-9]-[0-3][0-9]_[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$"`
	do
		# Convert the snapshot date into seconds since epoch
		EPOCH=$(date -d "`echo ${SUBVOL} | sed 's/_/ /'`" +%s)

		# If the snapshot is old enough
		if [ ${EPOCH} -lt ${WEEKSAGO} ]
		# If the snapshot is new enough
		#if [ ${EPOCH} -ge ${WEEKSAGO} ]
		then
			# Get a list of subvolume/snapshot names that have this date - ie those that are old enough
			for SNAP in `btrfs sub list ${FS} | grep "${SUBVOL}" | awk '{print $7}'`
			do
				# If the subvolume/snapshot exists at that folder then we delete it 
				[[ -d "${FS}/${SNAP}" ]] && btrfs sub delete ${FS}/${SNAP}
			done

			# This removes the parent folders which we created to hold the actual snapshot
			rm -rf ${FS}/backup/snapshots/${SUBVOL}*
		else
			echo "not old enough: ${SUBVOL}"
		fi

	done

done
