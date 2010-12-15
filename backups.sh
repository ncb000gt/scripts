#!/bin/sh
# Script poached from: http://www.cyberciti.biz/tips/how-to-backup-mysql-databases-web-server-files-to-a-ftp-server-automatically.html
# Hacked up by: Nick Campbell

DIRS=<replacewithdirs>

BACKUP=/tmp/backup.$$
NOW=$(date +"%d-%m-%Y")

INCFILE=<incrementalfile>

DAY=$(date +"%a")
FULLBACKUP="Sun"

### FTP server Setup ###
FTPD=<ftpdir>
FTPU=<ftpuser>
FTPP=<ftppass>
FTPS=<ftpserver>
NCFTP="$(which ncftpput)"

### Other stuff ###
EMAILID=<email to notify>

### Start Backup for file system ###
[ ! -d $BACKUP ] && mkdir -p $BACKUP || :
### See if we want to make a full backup ###
if [ "$DAY" == "$FULLBACKUP" ]; then
    FTPD=<ftpdir-fullbackup>
    FILE="fs-full-$NOW.tar.gz"
    tar -zcvf $BACKUP/$FILE $DIRS
else
    i=$(date +"%Hh%Mm%Ss")
    FILE="fs-i-$NOW-$i.tar.gz"
    tar -g $INCFILE -zcvf $BACKUP/$FILE $DIRS
fi

### Dump backup using FTP ###
#Start FTP backup using ncftp
ncftp -u"$FTPU" -p"$FTPP" $FTPS <<EOF
mkdir $FTPD
mkdir $FTPD/$NOW
cd $FTPD/$NOW
lcd $BACKUP
mput *
quit
EOF

### Find out if ftp backup failed or not ###
if [ "$?" == "0" ]; then
    rm -f $BACKUP/*
else
    T=/tmp/backup.fail
    echo "Date: $(date)">$T
    echo "Hostname: $(hostname)" >>$T
    echo "Backup failed" >>$T
    mail -s "BACKUP FAILED" "$EMAILID" <$T
    rm -f $T
fi