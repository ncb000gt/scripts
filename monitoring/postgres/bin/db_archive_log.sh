#
# Script to archive a single WAL log, called by Postgres.
#
# NOTE: the pg_archlogs symbolic link MUST be setup for this to work.

PATH=$1
FILE=`/bin/basename $PATH`
DEST="/var/lib/dba/pg_archlogs/$FILE"

# /var/lib/dba/alert.sh "db_archive_log.sh runing" "source: $PATH dest: $DEST"

if [ -f /var/lib/dba/pg_archlogs/disabled ] ; then
   # The existence of this file disabled WAL file archiving
   exit 0
fi

if [ ! -f $DEST ] ; then
   /bin/cp $PATH $DEST
   RC=$?
else
   RC=1
fi

if [ $RC -ne 0 ] ; then
   /var/lib/dba/alert.sh "db_archive_log.sh failure on `/bin/hostname`" "$0 $PATH"
fi
exit $RC

