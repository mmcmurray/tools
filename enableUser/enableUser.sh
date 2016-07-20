#!/bin/bash
# Date: 8/19/2010
# Creator: @Mike McMurray
# $Id: enableUser.sh.sh,v 1.00 2010-08-26 13:00:27-07 root Exp $

# Purpose: Script to enable or disable a user from the
# /data1/etc/allowed_users file on a timed basis.  This script will
# use the "at" command scheduler to disable a user after a set period
# of time.

ALERT_ADDR='mike.mcmurray@gmail.com'
BASEDIR='/data1/bin'
SCRIPTNAME=`basename "${0}"`
#USER_FILE='/data1/etc/authorized_users'
USER_FILE='/home/CORP/mmcmurray/code/enableUser/authorized_users'
HOURS='4'

# Obligatory usage() function
function usage() {
    echo ""
    echo "Purpose:"
    echo "    This script will either enable or disable access restrictions"
    echo "    for a defined user for a set period of time."
    echo ""
    echo "Usage:"
    echo "    $0 [-h] -e OR -d -u <user>"
    echo ""
    echo "Where:"
    echo "    -h = Print this Help Message."
    echo "    -e = Enable Access."
    echo "    -d = Disable Access."
    echo "    -u = The User to take action on."
    echo "    -t = Number of hours to enable the user for."
    echo ""
}

function errorAndExit() {
    usage
    echo "${SCRIPTNAME}::`date '+%Y-%m-%d %H:%M:%S'`: ERROR:  ${1}"
    exit 1
}

# Confirm this script is being run by the root user.  Return an error if not.
if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "${SCRIPTNAME}::`date '+%Y-%m-%d %H:%M:%S'`: ERROR:  This script must be run as root"
    exit 1
fi

# We always should expect arguments.  If none exist, we need to throw an error.
if [ $# -eq 0 ]; then usage ; exit 1; fi

# Usage: scriptname -options
# Note: dash (-) necessary
while getopts ":hedu:t:" Option; do
  case $Option in
    h ) usage 'HELP'; exit 0;;
    e ) ENABLE=1 ;;
    d ) ENABLE=0 ;;
    u ) ODUSER=${OPTARG} ;;
    t ) HOURS=${OPTARG} ;;
    * ) usage; echo "${SCRIPTNAME}::`date '+%Y-%m-%d %H:%M:%S'`: Internal ERROR!"; exit 1 ;;
  esac
done

shift $(($OPTIND - 1))
# Decrements the argument pointer so it points to next argument.

# If ${ODUSER} is not assigned, return with help.
if [ -z ${ODUSER} ] ; then
    errorAndExit "-u flag is required."
fi

# Confirm whether the user exists in the file and return an error if they
# do not.
if ! egrep ${ODUSER} ${USER_FILE} > /dev/null 2>&1; then 
    errorAndExit "User (${ODUSER}) does not exist in ${USER_FILE}"
fi

# If ENABLE is true
if [ ${ENABLE} -eq 1 ]; then

    # Check to see if the user already has an at job scheduled, so we can prompt to take necessary
    # action against it.
    if [ -f /tmp/enableUser.${ODUSER}.job ]; then
        jobArray=(`cat /tmp/enableUser.${ODUSER}.job`)
        echo "This user is already enabled and scheduled to be disabled at:"
        echo
        echo "    ${jobArray[4]} on ${jobArray[3]} with job #${jobArray[1]}"
        echo
        echo "Do you wish to continue and override the existing job? (yes/no)"
        read CONTINUE

        shopt -s nocasematch
        case "${CONTINUE}" in
            y|yes ) echo "Continuing and removing job #${jobArray[1]}"
                    atrm ${jobArray[1]};;
            n|no )  echo "Leaving existing job and exiting."
                    exit 0;;
        esac
    fi

    # Enable the user.
    echo "Enabling access for user ${ODUSER}"
    sed -i "s/^#\+${ODUSER}/${ODUSER}/" ${USER_FILE}

    # Create the command file to be used by at.
    cat > /tmp/enableUser.${ODUSER}.cmd <<EOF
/data1/bin/enableUser.sh -d -u ${ODUSER}
EOF
    # Log the message to syslog
    /usr/bin/logger -p local1.notice -t "enableUser[${PPID}]" "user ${ODUSER} enabled for OD server logins for (${HOURS}) hours."
    # Send an email to the relevant parties.
    /bin/mail -s "Notice: ${ODUSER} enabled for (${HOURS}) hours." ${ALERT_ADDR} <<EOF
enableUser[${PPID}]: user ${ODUSER} enabled for OD server logins.

    Start: `date`
    End: `date -d "${HOURS} hours"`
EOF

    # Create an 'at' job to disable the defined user
    # after a period of time.
    at -f /tmp/enableUser.${ODUSER}.cmd now + ${HOURS} hours > /tmp/enableUser.${ODUSER}.job 2>&1
fi

# If ENABLE is false
if [ ${ENABLE} -eq 0 ]; then
    echo "Disabling access for user ${ODUSER}"
    sed -i "s/^${ODUSER}/#${ODUSER}/" ${USER_FILE}
    /usr/bin/logger -p local1.notice -t "enableUser[${PPID}]" "user ${ODUSER} disabled for OD server logins."
    echo "enableUser[${PPID}] user ${ODUSER} disabled for OD server logins." | /bin/mail -s "Notice: ${ODUSER} disabled." ${ALERT_ADDR}

    # Cleanup after ourselves
    if [ -f /tmp/enableUser.${ODUSER}.cmd ]; then
        /bin/rm -f /tmp/enableUser.${ODUSER}.cmd
    fi

    # Remove the at job (if it still exists) and the job file.
    if [ -f /tmp/enableUser.${ODUSER}.job ]; then
        echo "Removing at job"
        jobArray=(`cat /tmp/enableUser.${ODUSER}.job`)
        atrm ${jobArray[1]}
        rm /tmp/enableUser.${ODUSER}.job
    fi
    

fi
