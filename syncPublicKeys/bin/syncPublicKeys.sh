#!/bin/bash

SCRIPTNAME=`basename "${0}"`
SMUSER='root'
REMOTE_HOST='bastion.domain.com'
USERFILE='/data1/etc/authorized_users'
KEYFILE='/data1/keyfiles/keys'
SERVERLIST='/data1/etc/servers.txt'
DATESTAMP=`date +%s`

# Cat all approved users public keys into a single authorized_keys file.
/bin/cat ${USERFILE} | while read user; do
    [[ ${user} =~ ".*\#.*" ]] && continue
    homedir=`getent passwd ${user} | cut -d: -f6`
    pubfile="${homedir}/.ssh/id_rsa.pub"
    if [ -f ${pubfile} ]; then
        echo -n "${SCRIPTNAME}: Found public key for ${user}.  Adding to master keys file... "
        /bin/cat ${pubfile} >> ${KEYFILE}.${DATESTAMP}.tmp
	echo 'done.'
    fi
done

# Move the file once everything is complete.
/bin/mv ${KEYFILE}.${DATESTAMP}.tmp ${KEYFILE}.${DATESTAMP}

# Confirm the file is in place before we attempt to push it over the wire. 
if [ -f ${KEYFILE}.${DATESTAMP} ]; then
    echo "${SCRIPTNAME}: Copying keyfile to OD hosts."

    # Loop through each OD server in question and copy the file over via ssh.
    /bin/cat ${SERVERLIST} | while read host; do
        [[ ${host} =~ ".*\#.*" ]] && continue
        [[ ${host} =~ "^$" ]] && continue
        echo -n "${SCRIPTNAME}: Sending master keyfile to ${host}... "
        if /bin/cat ${KEYFILE}.${DATESTAMP} | /usr/bin/ssh -o SendEnv=SMUSER -o SendEnv=REMOTE_HOST -q smdev@${host} '/bin/cat > .ssh/authorized_keys2' ; then
           echo 'done.'
        else
           echo 'something went horribly wrong.'
        fi
    done
fi
