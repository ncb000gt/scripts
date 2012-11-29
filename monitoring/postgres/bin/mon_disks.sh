#
# Monitors the Linux servers for general performance metrics and logs
# them in a postgres database.
#
# Usage:   mon_disks.sh <hostname | ALL> <insert>
#
# If insert = 1, log the stats, else just monitor and potentially alert.
#
# 01/12/2010 - Nathan Thom - Created
#

NUM=`ps -ef | grep $0 | grep -v grep | wc -l`
if [ $NUM -gt 50 ] ; then
   # previous script still running (each run will cause multiple processes)
   echo "$NUM scripts still running"
   exit 1
fi

. ~/.bash_profile

HOST=$1
INSERT=$2

mon_host () {

   HOST=$1

   LOG=/tmp/$$_df

   echo "`date`: Monitoring $HOST"

   ssh -n $HOST "df -mx tmpfs -x iso9660 -x nfs | grep -v Filesystem" > $LOG

   while read LINE; do
      NF="`echo $LINE | awk '{print NF}'`"
      if [ $NF -eq 5 ] ; then
         MOUNT="`echo $LINE | awk '{print $5}'`"
         SIZE="`echo $LINE | awk '{print $1}'`"
         USED="`echo $LINE | awk '{print $2}'`"
         if [ $INSERT ] ; then
            psql -U stats performance -c \
            "insert into stats.disks
             values (localtimestamp, '$HOST', '$MOUNT', $SIZE, $USED)"
         fi
      elif [ $NF -eq 6 ] ; then
         MOUNT="`echo $LINE | awk '{print $6}'`"
         SIZE="`echo $LINE | awk '{print $2}'`"
         USED="`echo $LINE | awk '{print $3}'`"
         if [ $INSERT ] ; then
            psql -U stats performance -c \
            "insert into stats.disks
             values (localtimestamp, '$HOST', '$MOUNT', $SIZE, $USED)"
         fi
      fi
      let PCT=100*$USED/$SIZE
      if [ $PCT -gt 98 ] ; then
         /var/lib/dba/alert.sh "ALERT: File System $MOUNT is at $PCT% on $HOST" "File System $MOUNT is at $PCT% on $HOST"
      fi
   done < $LOG

   rm $LOG
}

if [ "$HOST" = "ALL" ] ; then
   # get list of all monitored servers from ~/mon_targets.cfg
   while read HOST; do
      mon_host $HOST
   done < ~/mon_targets.cfg
else
   mon_host $HOST
fi

