#
# Monitors the size of every table in a database and logs
# them in a postgres database. Can generate a lot of data so only
# use on critical databases.
#
# Usage:  mon_tables.sh <hostname | ALL> <database> 
#
# 30/01/2011 - Nathan Thom - Created
#

NUM=`ps -ef | grep $0 | grep -v grep | wc -l`
if [ $NUM -gt 50 ] ; then
   # previous script still running (each run will cause multiple processes)
   echo "$NUM scripts still running"
   exit 1
fi

. ~/.bash_profile

HOST=$1
DB=$2

mon_host () {

   HOST=$1

   echo "`date`: Monitoring $HOST"

   ssh -n $HOST ". ~/.bash_profile; psql -U postgres $DB -c \
       \"copy ( " \
	"select current_timestamp, '$HOST', '$DB', n.nspname, c.relname, c.relkind, c.relpages, c.reltuples " \
	"from pg_class c, pg_namespace n " \
	"where c.relnamespace = n.oid " \
	"and n.nspname not in ('information_schema','pg_catalog') " \
	"and relkind != 'S' and relpages > 1 " \
	") to stdout\" " | psql -U stats performance -c "copy stats.table_sizes from stdin"

}

if [ "$HOST" = "ALL" ] ; then
   # get list of all monitored servers from ~/mon_targets.cfg
   while read HOST; do
      mon_host $HOST
   done < ~/mon_targets.cfg
else
   mon_host $HOST
fi
