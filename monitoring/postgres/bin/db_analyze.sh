#
# This script will perform an ANALYZE on a whole database. You can do all schemas or a single one.
# You can also specify how many parallel processes to use to speed up the processing.
# Designed to be run after restoring a database, not for day to day use as it will only pick
# up tables that have never been analyzed before.
#
# 2010/10/26 - Created by Nathan Thom
#

. ~/.bash_profile >/dev/null 2>&1

DBA_DIR="/var/lib/dba"

print_usage() {
   echo
   echo "Usage: $0 -d <db_name> [-n <schema_name>] [-p <parallel_processes>]"
   echo
   echo "Example: $0 -d property_au"
   echo "         $0 -d property_au -n property"
   echo "         $0 -d property_nz -p 4"
   echo
}

if [ $# -lt 2 ] ; then
   print_usage
   exit 1
fi

NUM_PROCESSES=1
SCHEMA=''
while getopts "d:p:n:" options; do
   case $options in
      d ) DB=`echo $OPTARG`;;
      p ) NUM_PROCESSES=$OPTARG;;
      n ) SCHEMA=$OPTARG;;
      \? ) print_usage;;
      * ) print_usage;;
   esac
done

if [ "$SCHEMA" != "" ] ; then
   SCHEMA="and schemaname = '$SCHEMA' "
fi

analyze_table() {
   SQL=$1
   psql $DB -c "$SQL"
   echo >&4
}

echo "Starting analyze at `date`"

# Build up analyze statement for each table separately. Do the biggest ones first to try and spread
# the work between the slave processes as evenly as possible.

psql $DB -At -o /tmp/$$.list -c "select 'analyze verbose ' || s.schemaname || '.' || s.relname || ';' \
        from pg_stat_all_tables s, pg_class c, pg_namespace n \
        where c.relname = s.relname and s.schemaname = n.nspname and n.oid = c.relnamespace \
        and s.last_analyze is null and s.last_autoanalyze is null and s.schemaname != 'pg_toast' \
        $SCHEMA order by c.relpages desc"

# Create a pipe for slave processes to indicate when they are done
mkfifo /tmp/$$.pipe; exec 4<>/tmp/$$.pipe

LINE_NUM=0
while read TABLE
do
   if [ $LINE_NUM -lt $NUM_PROCESSES ] ; then

      # start initial slave processes
      analyze_table "$TABLE" &

   else

      # wait for one of the slave processes to finish
      while read; do
         break
      done <&4

      # start the next one
      analyze_table "$TABLE" &

   fi

   let LINE_NUM=$LINE_NUM+1
done < /tmp/$$.list

wait

rm /tmp/$$.list
rm /tmp/$$.pipe

echo "Completed analyze at `date`"

