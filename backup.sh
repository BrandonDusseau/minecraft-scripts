#!/bin/bash
# Minecraft Backup Script v1.1.0

# File and directory configuration
# Ensure these directories have correct permissions
# Do not add trailing slashes
MCDIR="/home/your_user/minecraft"
BACKUPDIR="${MCDIR}/backups"

# Log location - set to false to disable logging (not recommended)
LOGFILE="${MCDIR}/backup.log"

# Revision directories
# These directories MUST all be on the same filesystem as BACKUPDIR
ONDEMANDDIR=${BACKUPDIR}
HOURLYDIR=${BACKUPDIR}/hourly
DAILYDIR=${BACKUPDIR}/daily
WEEKLYDIR=${BACKUPDIR}/weekly
MONTHLYDIR=${BACKUPDIR}/monthly

# Increments of time on which to back up
HOURLY=true
DAILY=true
WEEKLY=true
MONTHLY=true

# How many revisions to retain (0 for infinite)
RETAINHOURS=24
RETAINDAYS=7
RETAINWEEKS=5
RETAINMONTHS=12

# Name of Minecraft screen session
MCSCREENNAME="minecraft"


WORLDNAME=$(grep "level-name" $MCDIR/server.properties | cut -d'=' -f2)

### Do not modify below this line unless you know what you are doing! ###

mcsend() {
	# $1 - Command to send
	if mcrunning; then
		screen -S $MCSCREENNAME -X stuff "$1\n"
	fi
}

mcsay() {
	# $1 - Message to send
	mcsend "say [§3Backup§r] $1"
}

logmsg() {
	# $1 - Message to log
	if [ "$LOGFILE" = false ]; then
		return
	fi

	# Accept argument or stream from STDIN
	if [ -n "$1" ]; then
		IN="$1"
	else
		read IN
	fi

	if [ -n "$IN" ]; then
		echo "`date +"%Y-%m-%d %H:%M:%S"` mcbackup[$$]: $IN" >> $LOGFILE
	fi
}

enablesave() {
	# FIXME: Remove this when save-off works correctly
	chmod -R u+w $MCDIR/$WORLDNAME/playerdata
	chmod -R u+w $MCDIR/$WORLDNAME/stats
	mcsend "save-on"
}

err() {
	# $1 - Message to log
	logmsg "[ERROR] $1"
	mcsay "§cBackup §cfailure"
	exit 1
}

fileage() {
	# $1 - Directory to search
	# $2 - Formatting string
	find $1 -maxdepth 1 -name $(ls -t $1 | grep -G "World_${WORLDNAME}_.*\.tar\.gz" | head -1) -printf $2
}

hasfile() {
	# $1 - Directory to check
	if [ $(numfiles $1) != 0 ]; then
		true
	else
		false
	fi
}

numfiles() {
	# $1 - Directory to check
	ls $1 | grep -G "World_${WORLDNAME}_.*\.tar\.gz" | wc -l
}

PURGEFAIL=false
purgefiles() {
	# $1 - Directory in which to purge
	# $2 - Number of files to preserve (0 disables purging)

	# Only purge if retention is 0 or files exceed maximum number
	FILESINDIR=$(numfiles $1)
	if [ $2 -gt 0 ] && [ $FILESINDIR -gt $2 ]; then
		NUMTOPURGE=$(($FILESINDIR - $2))
		logmsg "Purging ${NUMTOPURGE} backup(s) from ${1}."

		# DANGER ZONE - Delete files matching above script
		FILENUM=0
		while [ $FILENUM -lt $NUMTOPURGE ]
		do
			FILENUM=$(($FILENUM + 1))
			FILE= read -rd $'\0' line < <(
				find $1 -maxdepth 1 -type f -printf '%T@ %p\0' 2>/dev/null |
				grep -ZzG "World_${WORLDNAME}_.*\.tar\.gz" |
				sort -zn
			)
			TOPURGE="${line#* }"
			logmsg "Purging backup file ${TOPURGE}"
			if ! $(rm ${TOPURGE} 2>&1 | logmsg ; test ${PIPESTATUS[0]} -eq 0); then
				PURGEFAIL=true
				logmsg "[WARNING] Failed to purge a backup; stopping purge."
				break;
			fi
		done
	fi
}

mcrunning() {
	$(pidof minecraft &>/dev/null)
	ismcrunning=$?

	if $(screen -ls | grep -q "$MCSCREENNAME") && [ ismcrunning = 0 ]; then
		return 1
	else
		return 0
	fi
}

# Do not send console commands if MC or screen are not running
# NOTE: This relies on the Minecraft server process being named "minecraft"
mcrunning
if mcrunning; then
	: # noop
else
	logmsg "WARN: Minecraft is not running or is inaccessible; not sending commands to console."
fi

logmsg "Backup started"

# Determine whether to run on a schedule
if [ "$1" == "-s" ]; then
	SCHEDULE=true
else
	SCHEDULE=false
fi

# Generate a filename
STARTDATE=$(date +"%Y-%m-%d %H:%M:%S")
FILEPREFIX="World_${WORLDNAME}_$(date +"%Y-%m-%d_%H.%M.%S" --date="$STARTDATE")"

# If running on a schedule, check if backups are necessary
if [ "$SCHEDULE" = true ]; then
	DOBACKUP=false

	# Hourly backups can run if directory is missing, or if the year, day of the year, or hour
	# of the day do not match the current time.
	if ([ "$HOURLY" = true ] && (
		[ ! -d $HOURLYDIR ] ||
		((! $(hasfile $HOURLYDIR)) ||
		[ $(fileage $HOURLYDIR "%TY") != $(date +"%Y" --date="$STARTDATE") ] ||
		[ $(fileage $HOURLYDIR "%Tj") != $(date +"%j" --date="$STARTDATE") ] ||
		[ $(fileage $HOURLYDIR "%TH") != $(date +"%H" --date="$STARTDATE") ])
	)); then
		DOBACKUP=true
	else
		HOURLY=false
	fi

	# Daily backups can run if directory is missing, or if the year or day of the year
	# do not match the current time.
	if ([ "$DAILY" = true ] && (
		[ ! -d $DAILYDIR ] ||
		((! $(hasfile $DAILYDIR)) ||
		[ $(fileage $DAILYDIR "%TY") != $(date +"%Y" --date="$STARTDATE") ] ||
		[ $(fileage $DAILYDIR "%Tj") != $(date +"%j" --date="$STARTDATE") ])
	)); then
		DOBACKUP=true
	else
		DAILY=false
	fi

	# Weekly backups can run if directory is missing, or if the year or week of the year do
	# not match the current time.
	if ([ "$WEEKLY" = true ] && (
		[ ! -d $WEEKLYDIR ] ||
		((! $(hasfile $WEEKLYDIR)) ||
		[ $(fileage $WEEKLYDIR "%TY") != $(date +"%Y" --date="$STARTDATE") ] ||
		[ $(fileage $WEEKLYDIR "%TW") != $(date +"%W" --date="$STARTDATE") ])
	)); then
		DOBACKUP=true
	else
		WEEKLY=false
	fi

	# Monthly backups can run if directory is missing, of if the year or month do not match
	# the current time.
	if ([ "$MONTHLY" = true ] && (
		[ ! -d $MONTHLYDIR ] ||
		((! $(hasfile $MONTHLYDIR)) ||
		[ $(fileage $MONTHLYDIR "%TY") != $(date +"%Y" --date="$STARTDATE") ] ||
		[ $(fileage $MONTHLYDIR "%Tm") != $(date +"%m" --date="$STARTDATE") ])
	)); then
		DOBACKUP=true
	else
		MONTHLY=false
	fi


	# If no scheduled backups are needed, exit
	if [ "$DOBACKUP" = false ]; then
		logmsg "Scheduled backups already up to date; aborting."
		exit 0
	fi
fi

# Make backup directory if needed
if [ ! -d "$BACKUPDIR" ]; then
	mkdir "$BACKUPDIR"
fi

# Send a warning message to the server and disable saving
mcsay "Backup started."
mcsend "save-off"

# Workaround to lock playerdata and stats while saving is turned off
# See https://bugs.mojang.com/browse/MC-3208
# FIXME: Remove this when save-off works correctly
chmod -R u-w $MCDIR/$WORLDNAME/playerdata
chmod -R u-w $MCDIR/$WORLDNAME/stats

# Back up the world to a temorary location
# NOTE: This must be on the same filesystem as the backup target directory
TEMPFILE=$BACKUPDIR/.mcbackup.tar
# FIXME: Remove permissions override when above mentioned bug is resolved
if ! $(tar --mode="a+rw" -cf $TEMPFILE -C $MCDIR $WORLDNAME 2>&1 | logmsg ; test ${PIPESTATUS[0]} -eq 0); then
	enablesave
	rm $TEMPFILE 2>/dev/null
	err "Unable to generate tar file. Aborting."
fi

# Allow server to begin saving again
enablesave

# Check if anything has changed since the last backup
SUMFILE=$MCDIR/backup.md5
if md5sum --status -c $SUMFILE 2>/dev/null; then
	NOCHANGE=true
else
	NOCHANGE=false
	md5sum $TEMPFILE > $SUMFILE
	if ! $(gzip -fq $TEMPFILE 2>&1 | logmsg ; test ${PIPESTATUS[0]} -eq 0); then
		rm $TEMPFILE 2>/dev/null
		err "Unable to generate gzip file. Aborting."
	fi
	TEMPFILE=${TEMPFILE}.gz
fi

# Only perform backups if something has changed
BACKUPRUN=false
BACKUPFAIL=false
if [ "$NOCHANGE" = false ]; then
	# Create scheduled files if the schedule is enabled
	if [ "$SCHEDULE" = true ]; then
		# Perform the hourly backup if enabled
		if [ "$HOURLY" = true ]; then
			# Create the hourly backup directory if it does not already exist
			if [ ! -d $HOURLYDIR ]; then
				mkdir -p $HOURLYDIR
			fi

			# Hard link the hourly backup to the temporary file
			if $(
				ln $TEMPFILE $HOURLYDIR/${FILEPREFIX}.tar.gz 2>&1 |
				logmsg;
				test ${PIPESTATUS[0]} -eq 0
			); then
				logmsg "Performed hourly backup"
				BACKUPRUN=true

				# Purge outdated files
				purgefiles $HOURLYDIR $RETAINHOURS
			else
				logmsg "[WARNING] Failed to complete hourly backup"
				BACKUPFAIL=true
			fi
		fi

		# Perform the daily backup if enabled
		if [ "$DAILY" = true ]; then
			# Create the daily backup directory if it does not already exist
			if [ ! -d $DAILYDIR ]; then
				mkdir -p $DAILYDIR
			fi

			# Hard link the daily backup to the temporary file
			if $(
				ln $TEMPFILE $DAILYDIR/${FILEPREFIX}.tar.gz 2>&1 |
				logmsg;
				test ${PIPESTATUS[0]} -eq 0
			); then
				logmsg "Performed daily backup"
				BACKUPRUN=true

				# Purge outdated files
				purgefiles $DAILYDIR $RETAINDAYS
			else
				logmsg "[WARNING] Failed to complete daily backup"
				BACKUPFAIL=true
			fi
		fi

		# Perform the weekly backup if enabled
		if [ "$WEEKLY" = true ]; then
			# Create the weekly backup directory if it does not already exist
			if [ ! -d $WEEKLYDIR ]; then
				mkdir -p $WEEKLYDIR
			fi

			# Hard link the weekly backup to the temporary file
			if $(
				ln $TEMPFILE $WEEKLYDIR/${FILEPREFIX}.tar.gz 2>&1 |
				logmsg;
				test ${PIPESTATUS[0]} -eq 0
			); then
				logmsg "Performed weekly backup"
				BACKUPRUN=true

				# Purge outdated files
				purgefiles $WEEKLYDIR $RETAINWEEKS
			else
				logmsg "[WARNING] Failed to complete weekly backup"
				BACKUPFAIL=true
			fi
		fi

		# Perform the monthly backup if enabled
		if [ "$MONTHLY" = true ]; then
			# Create the monthly backup directory if it does not already exist
			if [ ! -d $MONTHLYDIR ]; then
				mkdir -p $MONTHLYDIR
			fi

			# Hard link the monthly backup to the temporary file
			if $(
				ln $TEMPFILE $MONTHLYDIR/${FILEPREFIX}.tar.gz 2>&1 |
				logmsg;
				test ${PIPESTATUS[0]} -eq 0
			); then
				logmsg "Performed monthly backup"
				BACKUPRUN=true

				# Purge outdated files
				purgefiles $MONTHLYDIR $RETAINWEEKS
			else
				logmsg "[WARNING] Failed to complete monthly backup"
				BACKUPFAIL=true
			fi
		fi

	else
		# Create on-demand backup if this is not a schedule run
		logmsg "Performed backup on demand"
		ln $TEMPFILE $BACKUPDIR/${FILEPREFIX}.tar.gz
		BACKUPRUN=true
	fi

	# Always link the last backup to latest if a backup ran and did not fail
	if [ "$BACKUPFAIL" = false ]; then
		if [ "$BACKUPRUN" = true ]; then
			rm $BACKUPDIR/latest.tar.gz 2>/dev/null
			ln $TEMPFILE $BACKUPDIR/latest.tar.gz
			logmsg "Backup completed successfully"
		else
			logmsg "Scheduled backups are already up to date"
		fi
	fi
else
	logmsg "No change was detected in the world file; backup stopped"
fi

# Remove the temporary file
rm $TEMPFILE

# If there was a purge failure, notify the server
if [ "$PURGEFAIL" = true ]; then
	mcsay "§cPurge §cfailure §c- §ccheck §clog §cfile"
fi

# Display appropriate message, depending on backup status
if [ "$BACKUPFAIL" = false ]; then
	mcsay "Backup complete."
else
	err "Unable to complete all backups."
fi
