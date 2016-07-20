#!/bin/sh

MASTERLIST='/home/CORP/mmcmurray/servers/od.*.all'
OUTFILE='/data1/etc/servers.txt'

for i in `ls ${MASTERLIST}`; do
    echo "# ${i}"
    cat ${i}
    echo
done > ${OUTFILE}
