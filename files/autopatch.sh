#!/bin/bash

# Automated patching script for RHEL and Debian/Ubuntu-based systems

# Reboot automatically after kernel update?
AUTO_REBOOT=0;

# Delay in minutes when running reboot command (logged-in users will be notified)
REBOOT_DELAY=5;

# Reboot notification message to logged-in users
REBOOT_MESSAGE="Applying security updates";

# Only do security updates by default,
# set this to 1 to do a full update
DO_FULL_UPGRADE=0;

# Safe mode: do not actually patch or reboot, just notify
SAFE_MODE=0;

# When to auto-reboot
# Options:
#	 now (just reboot after patching)
#	 HH24 MM format (e.g. 06 45) - reboot the next time we hit this timestamp
#	 DD HH24 MM format (e.g. 1 06 45) - reboot the next time the dat/timestamp match (day num is 0(sun)-6(sat), date's %w)
AUTO_REBOOT_WHEN="4 8 02"; # During at-risk

# Only do an auto-reboot if this command succeeds
# Useful to avoid rebooting e.g. a DHCP server when no other DHCP servers are up!
AUTO_REBOOT_ONLYIF="";

# Who to notify about patch updates and reboots
NOTIFY_EMAIL="root";
FROM_EMAIL="root";

# Where to log what we're doing
LOGFILE="/var/log/autopatch.log";

# Log to STDOUT instead of a logfile (for testing)
LOG_TO_STDOUT=0;

# Now load any per-host settings
if [ -f /etc/autopatch.conf ]; then
	. /etc/autopatch.conf;
fi;
BASE=$(readlink -f $0);
BASE=$(dirname $BASE);
BASE=$(dirname $BASE);
if [ -f $BASE/etc/autopatch.conf ]; then
	. $BASE/etc/autopatch.conf;
fi;

# Config processing and automatic stuff
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
HOSTNAME=$(hostname --fqdn);
REBOOT_CMD="/sbin/shutdown -r +$REBOOT_DELAY '$REBOOT_MESSAGE'";

# Writes a log message
function log {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1";
}

# Performs the actual reboot sequence with onlyif checks
function initiateReboot {
	if [ ! -z "$AUTO_REBOOT_ONLYIF" ]; then
		eval $AUTO_REBOOT_ONLYIF;
		if [ $? -ne 0 ]; then
			log "Will not reboot - ONLYIF condition not met ($AUTO_REBOOT_ONLYIF)";
			return 1;
		else
			log "ONLYIF condition is OK, will attempt auto-reboot";
		fi;
	fi;
	if [ $SAFE_MODE -eq 0 ]; then
		for to in $NOTIFY_EMAIL; do
			log "Notifying $to...";
	 		/bin/echo -e "From:$FROM_EMAIL\nTo:$to\nSubject:Auto-rebooting $HOSTNAME to apply patches in $REBOOT_DELAY minutes\n\nTo abort, run shutdown -c" | sendmail -t -f$FROM_EMAIL;
		done;

		log "Run reboot command: $REBOOT_CMD";
		$REBOOT_CMD;
	else
		log "Would start reboot: $REBOOT_CMD";
	fi;

}

# Does the auto-reboot at the specified time
function doAutoReboot {

	# Now...
	UNIXTIME=$(date +%s);
	DAY_NOW=$(date +%w);
	HOUR_NOW=$(date +%H);
	MIN_NOW=$(date +%M);

	# Funge the reboot timestamp into an array...
	AUTO_REBOOT_WHEN=($AUTO_REBOOT_WHEN);

	# Special case for "reboot after patch"
	if [ "$AUTO_REBOOT_WHEN" == 'now' ]; then
		log "Planned reboot NOW";
		initiateReboot;

	# Reboot at timestamp: let 'at' deal with it...
	elif [ ${#AUTO_REBOOT_WHEN[@]} -eq 2 ]; then
		REBOOT_HOUR=${AUTO_REBOOT_WHEN[0]};
		REBOOT_MIN=${AUTO_REBOOT_WHEN[1]};
		log "Planned reboot at timestamp $REBOOT_HOUR:$REBOOT_MIN";

		if [ $SAFE_MODE -eq 0 ]; then
			echo "$0 --do-reboot" | at $REBOOT_HOUR:$REBOOT_MIN 2>&1;
		else
			log "Would schedule reboot: $0 --do-reboot | at $REBOOT_HOUR:$REBOOT_MIN 2>&1";
		fi;

	# Reboot on specific day/timestamp: work out how many days in the
	# future it is, then let 'at' deal with it...
	elif [ ${#AUTO_REBOOT_WHEN[@]} -eq 3 ]; then
		REBOOT_DAY=${AUTO_REBOOT_WHEN[0]};
		REBOOT_HOUR=${AUTO_REBOOT_WHEN[1]};
		REBOOT_MIN=${AUTO_REBOOT_WHEN[2]};

		if [ $REBOOT_DAY -ge $DAY_NOW ]; then
			add_days=$((REBOOT_DAY-DAY_NOW));
		else
			add_days=$((REBOOT_DAY+7 - DAY_NOW));
		fi;

		log "Planned reboot in $add_days days";
		if [ $SAFE_MODE -eq 0 ]; then
			echo "$0 --do-reboot" | at $REBOOT_HOUR:$REBOOT_MIN 2>&1;
		else
			log "Would schedule reboot: $0 --do-reboot | at $REBOOT_HOUR:$REBOOT_MIN + $add_days days 2>&1";
		fi;

	# OK, I have no idea what you're trying to do. Flail.
	else
		log "Unknown auto-reboot time, will NOT auto-reboot..." >&2;
	fi;
}

function isUp {

	if [ -z $1 ]; then
		return 2;
	fi;
	ping -c 1 -W 1 "$1" 2>&1 >/dev/null
	status=$?;
	return $status;
}

function isListening {

	if [ -z $1 ] || [ -z $2 ]; then
		return 2;
	fi;

	isUp $1 || return $?;
	nc -w 1 "$1" "$2" </dev/null >/dev/null;
	status=$?;
	return $status;
}

SUCCESS=1;

if [ $LOG_TO_STDOUT -eq 0 ]; then
	exec >$LOGFILE;
fi;


# If called with --do-reboot, then we should notify people and start the
# shutdown process. We will also do our 'onlyif' checks.
if [[ "$1" == "--do-reboot" ]]; then
	log "Initiating reboot sequence...";
	initiateReboot;
	exit 0;
fi;


log "Security updates starting";

if [ -e /etc/redhat-release ]; then

	log "Updating RHEL system '$(hostname --fqdn)' - safe mode is $SAFE_MODE";

	if [ $SAFE_MODE -eq 0 ]; then
		# Make sure yum is nice and clean and consistent first
		yum clean all 2>&1;
		if [ "$DO_FULL_UPGRADE" == "1" ]; then
			yum -y update 2>&1 || SUCCESS=0;
		else
			yum -y --security update 2>&1 || SUCCESS=0;
		fi;
	fi;

	# Check to see if we need a reboot, emulate debian's reboot-required file
	LAST_KERNEL=$(rpm -q --last kernel | perl -pe 's/^kernel-(\S+).*/$1/' | head -1);
	CURRENT_KERNEL=$(uname -r);
	test $LAST_KERNEL = $CURRENT_KERNEL || test "$LAST_KERNEL.$(arch)" = $CURRENT_KERNEL || touch /var/run/reboot-required;

elif [ -e /etc/debian_version ]; then
	log "Updating Debian/Ubuntu system '$(hostname --fqdn)'";

	if [ $SAFE_MODE -eq 0 ]; then
		aptitude update 2>&1 || SUCCESS=0;

		if [ "$DO_FULL_UPGRADE" == "1" ]; then
			aptitude safe-upgrade -o Aptitude::Delete-Unused=false --assume-yes 2>&1 || SUCCESS=0;
		else
			aptitude safe-upgrade -o Aptitude::Delete-Unused=false --assume-yes --target-release `lsb_release -cs`-security 2>&1 || SUCCESS=0;
		fi;
	fi;

# Don't know about anything but debian and redhat things :-(
else
	log "Cannot find /etc/redhat-release or /etc/debian_version, will not attempt patching" >&2;
	SUCCESS=0;
fi;


if [ $SUCCESS == 1 ]; then
	SUBJECT="Automatic updates for $HOSTNAME successful";
else
	SUBJECT="Automatic updates for $HOSTNAME FAILED";
fi;

if [ -f /var/run/reboot-required ]; then
	log "A reboot is required";
	if [ "$AUTO_REBOOT" == "1" ]; then
		SUBJECT="$SUBJECT: Server will be automatically rebooted";
		doAutoReboot || log "Auto-reboot failed";
	else
		SUBJECT="$SUBJECT: reboot required, please reboot the server when convenient";
	fi;
else
	SUBJECT="$SUBJECT: No reboot is required";
	log "No reboot is required";
fi;


if [ $SAFE_MODE -eq 0 ]; then
	for to in $NOTIFY_EMAIL; do
		log "Notifying $to...";
		(
			/bin/echo -e "From:$FROM_EMAIL\nTo:$to\nSubject:$SUBJECT\n\n";
			/bin/echo "Log:";
		/bin/cat $LOGFILE;
		) | sendmail -t -f$FROM_EMAIL;
	done;
fi;


