# Minecraft Server Automation Scripts #

This script package contains a startup and advanced backup script for Minecraft
servers. These scripts are easily configurable and require minimal experience
with Unix-like operating systems to use.

The startup script starts up the Minecraft server inside a `screen` session,
allowing the server console to run in the background, even if there are no
terminal sessions open on the server. This also allows the backup script to
send messages and commands to the Minecraft server.

The backup script can be run both on a schedule and on-demand (see *Usage*
section for more info). It can create hourly, daily, weekly, and monthly
backups and can be configured to automatically remove scheduled backup files
over time. This script utilizes _hard links_ to connect files created at the
same time, conserving disk space. The script also intelligently determines if
a backup is necessary and will not place extra load on the server if it is not.

## System Requirements ##
A Unix-like operating system (e.g. GNU/Linux, BSD, OS X) with `screen` and
`bash` installed.

## Setup ##

### 1. Download scripts ###
Clone/download this repository and place the scripts anywhere on the server,
preferably in your Minecraft server directory.

### 2. Configure scripts ###
*Startup script*

Open `startmc.sh` and change the following options to your liking:
* `MCDIR` - Set this to your Minecraft server directory. It's best to use the
  full path to your server directory (e.g. `"/home/brandon/minecraft"`) so the
	script can be easily moved later. **Do NOT include a `/` on the end!**
* `JVMARGS` - Set your Java arguments here. You can find more information on
  these elsewhere.
* `MCJAR` - The filename of your Minecraft server JAR file.
* `MCSCREENNAME` - The name of the `screen` session. **Do not include spaces!**

*Backup script*

Open `backup.sh` and change the following options to your liking:
* NOTE: Do not include a trailing slash (a `/` on the end) on any file paths
  in these settings.
* `MCDIR` - Set this to your Minecraft server directory. It's best to use the
  full path to your server directory (e.g. `"/home/brandon/minecraft"`) so the
	script can be easily moved later.
* `BACKUPDIR` - Set this to the directory where you'd like your backups to
  be stored. This can be anywhere on the system.
* `LOGFILE` - Set this to the file where you want log output stored. If you do
  not wish to keep a backup log, set this to `false` (without quotes). Disabling
	log output is not recommended, as you will not be notified of any errors the
	script encounters.
* `ONDEMANDDIR`, `HOURLYDIR`, `DAILYDIR`, `WEEKLYDIR`, `MONTHLYDIR` - Set these
  to the locations where you wish to store on-demand backups, hourly backups,
	daily backups, weekly backups, and monthly backups, respectively. These do not
	necessarily have to be in the backup directory, but it is recommended. These
	locations MUST be different from each other, and they MUST be located on
	the same filesystem as the `BACKUPDIR`, even if they are not inside
	`BACKUPDIR`.
* `HOURLY`, `DAILY`, `WEEKLY`, `MONTHLY` - Set these to `true` to
  enable scheduled backups at the respective intervals, or `false` to disable.
* `RETAINHOURS`, `RETAINDAYS`, `RETAINWEEKS`, `RETAINMONTHS` - Set these to the
  number of hourly, daily, weekly, and monthly backups, respectively, to keep.
	Set these to `0` to keep backups forever.
* `MCSCREENNAME` - The name of the `screen` session in which the Minecraft
  server runs.

## Usage ##

Note: In all examples, `$` indicates a shell prompt. You should not type this
when running your commands.

To use these scripts, you must first make them executable. To do this, run the
following command as whichever user you will run your Minecraft server on.

	$ cd /path/to/your/scripts
	$ chmod +x backup.sh startmc.sh

*Startup script*

To start the Minecraft server, simply run

	$ /path/to/your/scripts/startmc.sh

If you are already in the directory the script is in, use `./startmc.sh`
instead.

You can connect to the `screen` session running Minecraft with the following
command (replace `SCREENNAME` with the name you set in `startmc.sh`)

	$ screen -rS SCREENNAME

If you need to check if the `screen` session is running or do not remember the
name, just run

	$ screen -ls

Note that if the Minecraft server crashes or is stopped, the `screen` session
will not terminate by itself. You will need to connect to the session with
the above command and run `exit` to terminate before restarting the session.
This issue may be fixed in a future version of the script.

*Backup script*

The backup script has two modes: on-demand and schedule.

You can create an on-demand backup at any time by running

	$ /path/to/your/scripts/backup.sh

This will create a backup file in the location set in `ONDEMANDDIR` each time
it is run. If the Minecraft world has not changed since the last backup, an
on-demand backup will not be created.

To run the script on a schedule, instead use

	$ /path/to/your/scripts/backup.sh -s

This will run the script in backup mode, and will create backups for all of
the time intervals which have not had a recent enough backup. If the Minecraft
world has not changed since the last backup, scheduled backups will not be
created.

No matter which mode the script is run in, a file called `latest.tar.gz` will
always be created in the backup directory. This file will contain the latest
backup regardless of where it was placed.

When the backup script is run, a `backup.md5` file is created in the Minecraft
server directory. This file contains the checksum of the tar file generated
while the backup is being created. The script uses this file to determine if
anything has changed in the Minecraft world since the last backup run. Deleting
this file will cause the script to skip this check on the next run.

## Automating the Scripts ##

You can use `cron` to schedule the scripts to run automatically on your server.

To open the `cron` file, run the following command as the user which will run
the Minecraft server.

	$ crontab -e

NOTE: The startup script is currently designed to be run on-demand or on
reboot. If the script is run again while the server is running, it may fail or
create a conflicting `screen` session.

To start the Minecraft server on boot, add the following line to the `crontab`:

	@reboot /full/path/to/your/scripts/startmc.sh

It is important to use the full path here, as the system may not recognize
a relative (partial) path at the time this command is run.

On Ubuntu-based systems (including Linux Mint and some others), you may need
to change this command to

	@reboot sleep 30 && /full/path/to/your/scripts/startmc.sh

This is because Ubuntu-based systems do not always set up the appropriate
environment that `screen` requires before `cron`'s `@reboot` commands run,
which can cause Minecraft to fail to start on boot.

To run the backup script hourly, add the following line:

	0 * * * * /full/path/to/your/scripts/backup.sh -s

If you do not have hourly backups enabled, you may wish to instead run the
script daily, using `0 0 * * *` to run it at midnight.

`0 0 1 * *` will run the script on the first day of each month at Midnight, and
`0 0 * * 0` will run the script every Sunday at Midnight.

Running the script at a smaller interval (e.g. hourly) will also create larger
interval (daily, weekly, monthly) backups, so it is not necessary to add more
than one line to `crontab`.

You can run the script at other intervals as well, but it is recommended to run
it no more often than hourly so that your server experiences minimal load.
See https://en.wikipedia.org/wiki/Cron#Examples for more information on setting
intervals in `cron`.

Once you have added the appropriate number of lines, save your changes and the
new `crontab` will automatically be installed.

## Troubleshooting ##

If you have read this document thoroughly, you should not run into problems. If
you're still having trouble, try the below solutions:

*Startup script*

__Minecraft won't start with the script__

Make sure the options in `startmc.sh` are correct, and that your system has
`screen` installed. See the *Usage* section to find out how to check whether the
`screen` session is running. If it is, the problem may lie somewhere else.

Also make sure that the script has executable permissions and that it is running
as the same user that owns the Minecraft files.

__The script works by itself but won't run on boot__

Make sure that your `crontab` entry is correct and has the full path to the
script. If you're on an Ubuntu-based system, use the second version of the line
(with the `sleep`) shown in the *Automating the Scripts* section.

*Backup script*

__The backup script won't start__

Make sure the script has executable permissions and that it is running as the
same user that owns the Minecraft files. Also make sure that `screen` and
`bash` are installed on the server.

__The backup script always creates backups in the on-demand directory when it
should be scheduled.__

Make sure you have added the `-s` flag to the command to make it run with the
schedule.

__The backups/purges are failing__

Make sure the options in `backup.sh` are correct. Check the log file for more
information on why the backups are failing. If logging is disabled, enable it.

__The backups are failing and the log output says `permission denied`__

Make sure that the script is being run by the user that owns the Minecraft
server directory and backup directory. Make sure that both directories (and
all of the schedule directories) have correct permissions. At the very least,
these directories should have mode `700` (`drwx------`). By default they should
have mode `755` (`drwxr-xr-x`).

__The backups are failing and my log file isn't being created__

Make sure the user has permission to write to the location of the log file.

## Issues ##

If you find a problem with the script, please first check if you have the
latest version. If you have the latest version and the issue persists, please
file an issue on the GitHub repository.
