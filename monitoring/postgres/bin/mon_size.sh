#
# Monitors the size of the databases and tablespaces and logs
# them in a postgres database.
#
# Usage:  mon_size.sh <hostname | ALL>
#
# 05/10/2010 - Nathan Thom - Created
#

NUM=`ps -ef | grep $0 | grep -v grep | wc -l`
if [ $NUM -gt 50 ] ; then
   # previous script still running (each run will cause multiple processes)
   echo "$NUM scripts still running"
   exit 1
fi

. ~/.bash_profile

HOST=$1


mon_host () {

   HOST=$1

   echo "`date`: Monitoring $HOST"

   ssh -n $HOST ". ~/.bash_profile; psql -U postgres postgres -c \
       \"copy ( select localtimestamp, '$HOST', spcname, pg_tablespace_size(oid) from pg_tablespace ) to stdout\" " \
       | psql -U stats performance -c "copy stats.tablespace_sizes from stdin"

   ssh -n $HOST ". ~/.bash_profile; psql -U postgres postgres -c \
       \"copy ( select localtimestamp, '$HOST', pg_database.datname, pg_database_size(pg_database.datname) AS size FROM pg_database where datname not in ('template0','template1','postgres') ) to stdout\" " \
       | psql -U stats performance -c "copy stats.database_sizes from stdin"

}

if [ "$HOST" = "ALL" ] ; then
   # get list of all monitored servers from ~/mon_targets.cfg
   while read HOST; do
      mon_host $HOST
   done < ~/mon_targets.cfg
else
   mon_host $HOST
fi
