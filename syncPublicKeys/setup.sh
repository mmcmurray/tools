#!/bin/sh

SCRIPTNAME=`basename ${0}`
BASEPATH=`dirname ${0}`
cd ${BASEPATH}
BASEPATH=`pwd`
INSTALLPATH='/data1'

# Check to see if the prerequisite directories exist.  It not, let's create them.
DIRS=( 'etc' 'bin' 'keyfiles' )
for dir in ${DIRS[@]}; do
    echo -n "${SCRIPTNAME}: Checking ${dir} ... "
    dir="${INSTALLPATH}/${dir}"
    if [ ! -d ${dir} ]; then
        echo -n " not found.  Creating... "
        /bin/mkdir -p ${dir}
    fi
    echo 'done.'
done

# Copy the requisite files into their appropriate directories.
FILES=( 'etc/authorized_users' 'bin/genServerList.sh' 'bin/syncPublicKeys.sh' )
for file in ${FILES[@]}; do
    echo -n "${SCRIPTNAME}: Checking ${file} ... "
    if [ -f ${INSTALLPATH}/${file} ]; then
        echo -n 'exists.  Backing up ... '
        /bin/cp -fp ${INSTALLPATH}/${file} ${INSTALLPATH}/${file}.`date +%Y%m%d`
        echo 'done.'
    fi

    echo -n "${SCRIPTNAME}: Installing new ${file} ... "
    /bin/cp -f ${BASEPATH}/${file} ${INSTALLPATH}/${file}
    echo 'done.'
done
