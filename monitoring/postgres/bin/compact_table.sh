#!/bin/bash
#
# Created by depesz
#   http://www.depesz.com/index.php/2010/10/17/reduce-bloat-of-table-without-longexclusive-locks/
# 07/04/2011 - Updated by Nathan Thom with performance improvements
#

# Function definitions have to be here.
# For actual code ran when you run this script, search for "# MAIN PROGRAM #"

# Function    : show_reindexation_sql
# Description : Post-compating indexes of the table are usuallt quite
#             : bloated, so they should be reindexed. This functions shows
#             : how to do it.
show_reindexation_sql() {
    $PSQL -q -A -t -X -c "select pg_get_indexdef(indexrelid) from pg_index where indrelid = '$TABLE_SCHEMA.$TABLE_NAME'::regclass" | while read LINE
    do
        OLD_INDEX_NAME="$( echo "$LINE" | sed 's/ ON .*//' | awk '{print $NF}' )"
        echo "SELECT 'Size of index ($TABLE_SCHEMA.$OLD_INDEX_NAME) before reindex:', pg_relation_size('$TABLE_SCHEMA.$OLD_INDEX_NAME');"
        echo "$LINE" | sed 's/ ON /_new ON /;s/ INDEX / INDEX CONCURRENTLY /;s/$/;/'
        echo "DROP INDEX $TABLE_SCHEMA.$OLD_INDEX_NAME;"
        echo "ALTER INDEX $TABLE_SCHEMA.${OLD_INDEX_NAME}_new RENAME TO $OLD_INDEX_NAME;"
        echo "SELECT 'Size of index ($TABLE_SCHEMA.$OLD_INDEX_NAME) after reindex:', pg_relation_size('$TABLE_SCHEMA.$OLD_INDEX_NAME');"
    done
}

# Function    : recheck_page
# Description : Check the results of a page clean to see if any of the 
#               tuples moved to a place where we have already cleaned.
#               If necessary, call clean_page on the new page.
recheck_page() {
    CTID_FILE="$1"

        cat $CTID_FILE | while read LINE; do
            NEW_CTID=`echo $LINE | awk -F\| '{print $1}'`
            OLD_CTID=`echo $LINE | awk -F\| '{print $2}'`
            NEW_PAGE=${NEW_CTID%%,*}
            NEW_TUPLE=${NEW_CTID##*,}
            OLD_PAGE=${OLD_CTID%%,*}
            OLD_TUPLE=${OLD_CTID##*,}
            if [ $NEW_PAGE -gt $OLD_PAGE ] || ([ $NEW_PAGE -eq $OLD_PAGE ] && [ $NEW_TUPLE -lt $OLD_TUPLE ]) ; then
                printf "($OLD_CTID -> $NEW_CTID) re-cleaning $NEW_PAGE\n"
                clean_page $NEW_PAGE
                break
            fi
        done
        rm $CTID_FILE >/dev/null 2>&1

}

# Function    : clean_page
# Description : does updates on in the table, for every row in given page,
#             : up to the moment, when *all* rows are moved to earlier page,
#             : or *any* row is moved to later page
#             : Finishes also if there are no rows on the page.
clean_page() {
    USE_PAGE="$1"
    if (( "$USE_PAGE" < 0 ))
    then
        RETURN="ERROR"
        return
    fi
    #ti=$TUPLES_PER_PAGE+1
    ti=0
    
    # Do entire page's worth of tuples in one transaction. PostgreSQL really really likes to move tuples 
    # higher on the same page so if we count down we're stuffed. If we count up we get the same row over
    # and over again until it gets pushed off the page.

    SQL="set synchronous_commit = off; BEGIN; "
    while (( $ti < $TUPLES_PER_PAGE ))
    do
        ti=$(( $ti + 1 ))
	SQL="$SQL UPDATE $TABLE_SCHEMA.$TABLE_NAME SET $COLUMN_TO_UPDATE = $COLUMN_TO_UPDATE WHERE ctid = '($USE_PAGE,$ti)'::tid RETURNING ctid,'($USE_PAGE,$ti)';"
    done
    SQL="$SQL COMMIT;"
    SQL_FILE=/tmp/$$.$RANDOM.sql
    echo $SQL > $SQL_FILE
    CTID_FILE=/tmp/$$.$RANDOM.ctid
    $PSQL -q -A -t -X -f $SQL_FILE | tr -d "()" > $CTID_FILE
    if [ -s "$CTID_FILE" ] ; then
        if [ $USE_BG -eq 1 ] ; then
            # There were rows updated, check if they moved somewhere we have already processed.
            # Since this doesn't happen often, you could run this as a background process but
            # it might not be able to keep up.
            recheck_page $CTID_FILE &
        else
            recheck_page $CTID_FILE 
        fi
    else
        rm $CTID_FILE >/dev/null 2>&1
    fi
    rm $SQL_FILE >/dev/null 2>&1

    RETURN="ok"
    return
}


# Function    : get_base_settings
# Description : Gets base information from database - size of relation
#             : before all processing, page size, header size.
get_base_settings() {
    #TUPLES_PER_PAGE=$( psql -q -A -t -X -c "select current_setting('block_size')::int4 / sum(attlen) from pg_attribute where attrelid = '$TABLE_SCHEMA.$TABLE_NAME'::regclass and attnum < 0" )
    # Let's actually check what the max is to save some effort.
    #TUPLES_PER_PAGE=$( psql -q -A -t -X -c "select max(substring(ctid::varchar from strpos(ctid::varchar, ',')+1 for length(ctid::varchar)-1-strpos(ctid::varchar, ','))) from $TABLE_SCHEMA.$TABLE_NAME" )

    # Slower but more accurate method
    verbose_msg "Scanning table for highest tuple\n"
    $PSQL -q -A -t -X -c "SELECT substring(max(ctid)::varchar from 2 for strpos(max(ctid)::varchar, ',')-2)::int + 1, max(substring(ctid::varchar from strpos(ctid::varchar, ',')+1 for length(ctid::varchar)-1-strpos(ctid::varchar, ','))::int) from $TABLE_SCHEMA.$TABLE_NAME" > /tmp/$$.ctid
    TUPLES_PER_PAGE=`cat /tmp/$$.ctid | awk -F\| '{print $2}'`
    CURRENT_PAGE_COUNT=`cat /tmp/$$.ctid | awk -F\| '{print $1}'`
    rm /tmp/$$.ctid

#TUPLES_PER_PAGE=144
#CURRENT_PAGE_COUNT=3066925

    verbose_msg "At most, we can have %d tuples per page.\n" "$TUPLES_PER_PAGE"
    COLUMN_TO_UPDATE=$( psql -q -A -t -X -c "select quote_ident(attname) from pg_attribute where attrelid = '$TABLE_SCHEMA.$TABLE_NAME'::regclass and attnum > 0 and not attisdropped and attnum::text not in (select regexp_split_to_table(indkey::text, ' ') from pg_index where indrelid = '$TABLE_SCHEMA.$TABLE_NAME'::regclass) order by attnum asc limit 1" )
    if [[ -z "$COLUMN_TO_UPDATE" ]]
    then
        COLUMN_TO_UPDATE=$( psql -q -A -t -X -c "select quote_ident(attname) from pg_attribute where attrelid = '$TABLE_SCHEMA.$TABLE_NAME'::regclass and attnum > 0 and not attisdropped order by attnum asc limit 1" )
    fi
    if [[ -z "$COLUMN_TO_UPDATE" ]]
    then
        show_help_and_exit "Cannot find column to update. Does this table have any columns?"
    fi
    verbose_msg "Updates will be done on column: %s\n" "$COLUMN_TO_UPDATE"
}


# Function    : show_help_and_exit
# Description : Like the name suggests, it prints help page, and exits script
#             : If given args, treats them as format and arguments for printf
#             : and prints before help page
show_help_and_exit () {
    if (( $# > 0 ))
    then
        FORMAT="ERROR:\n$1\n\n"
        printf "$FORMAT" "${@:2:$#}" >&2
    fi
    cat <<_EO_HELP_
Syntax:
    $0 [arguments] [options]

Arguments:
    -n       : namespace in which table exists
    -t       : table name
    -k       : number of pages to try to free (per process) 
    -r       : read ahead pages (def 128)
Options:
    -U       : database user name
    -h       : database server host or socket directory
    -p       : database server port
    -d       : database name to connect to
    -c       : path to psql program
    -v       : show information while processing log files
    -i       : turn on initial vacuum
    -I       : turn off initial vacuum
    -f       : turn on final vacuum
    -F       : turn off final vacuum
    -r       : read ahead pages
    -b       : use background processes to speed up compaction

Defaults:
    -c psql -n public -k 10 -f -r 128

Description:

$0 connects to given table, and tries to compact given table, as described
in this blogpost:
http://blog.endpoint.com/2010/09/reducing-bloat-without-locking.html

_EO_HELP_
    exit
}

# Function    : verbose_msg
# Description : Calls printf on given args, but only if VERBOSE is on.
verbose_msg () {
    if (( $VERBOSE == 1 ))
    then
        printf "%s : " "$( date '+%Y-%m-%d %H:%M:%S' ) "
        printf "$@"
    fi
}

# Function    : read_arguments
# Description : Reads arguments from command line, and validates them
#             : default values are in "MAIN PROGRAM" to simplify finding them
read_arguments () {
    USE_BG=0
    while getopts ':U:h:p:d:c:n:t:k:r:xviIfFb' opt "$@"
    do
        case "$opt" in
            U)
                export PGUSER="$OPTARG"
                ;;
            h)
                export PGHOST="$OPTARG"
                ;;
            p)
                export PGPORT="$OPTARG"
                ;;
            d)
                export PGDATABASE="$OPTARG"
                ;;
            c)
                export PSQL="$OPTARG"
                ;;
            n)
                export TABLE_SCHEMA="$OPTARG"
                ;;
            t)
                export TABLE_NAME="$OPTARG"
                ;;
            k)
                export CLEAN_PAGES="$OPTARG"
                ;;
            i)
                export INITIAL_VACUUM="1"
                ;;
            I)
                export INITIAL_VACUUM="0"
                ;;
            f)
                export FINAL_VACUUM="1"
                ;;
            F)
                export FINAL_VACUUM="0"
                ;;
            x)
                EXTENDED_DEBUG=1
                ;;
            v)
                VERBOSE=1
                ;;
            r)
                RA="$OPTARG"
                ;;
            b)
                USE_BG=1
                ;;
            :)
                show_help_and_exit "Option -%s requires argument" "$OPTARG"
                ;;
            \?)
                if [[ "$OPTARG" == "?" ]]
                then
                    show_help_and_exit
                fi
                show_help_and_exit "Unknown option -%s" "$OPTARG"
                ;;
        esac
    done
    if [[ -z "$TABLE_SCHEMA" ]]
    then
        show_help_and_exit "Table schema (-n) cannot be empty!"
    fi
    if [[ -z "$TABLE_NAME" ]]
    then
        show_help_and_exit "Table name (-t) cannot be empty!"
    fi
    if [[ -z "$CLEAN_PAGES" ]]
    then
        show_help_and_exit "Clean pages (-k) cannot be empty!"
    fi
    if [[ ! "$CLEAN_PAGES" =~ ^[1-9][0-9]*$ ]]
    then
        show_help_and_exit "Number of pages to clean (%s) is not a valid number (1+, integer)" "$CLEAN_PAGES"
    fi
}

# MAIN PROGAM #

# default values for options
EXTENDED_DEBUG=0
VERBOSE=0
export TABLE_SCHEMA=public
export PSQL='psql'
export FINAL_VACUUM=1
# RA = 128 pages corresponds with a read ahead of 256 blocks which is default in Redhat.
export RA=128 
export CLEAN_PAGES=$RA

# Set locale to sane one, to speed up comparisons, and be sure that < and > on
# strings work ok.
export LC_ALL=C

# Read arguments from command line
read_arguments "$@"

# Print settings
verbose_msg "$0 Settings:
  - CLEAN_PAGES       : $CLEAN_PAGES
  - EXTENDED_DEBUG    : $EXTENDED_DEBUG
  - FINAL_VACUUM      : $FINAL_VACUUM
  - INITIAL_VACUUM    : $INITIAL_VACUUM
  - PGDATABASE        : $PGDATABASE
  - PGHOST            : $PGHOST
  - PGPORT            : $PGPORT
  - PGUSER            : $PGUSER
  - PSQL              : $PSQL
  - TABLE_NAME        : $TABLE_NAME
  - TABLE_SCHEMA      : $TABLE_SCHEMA
  - VERBOSE           : $VERBOSE
  - READAHEAD         : $RA
"

# Turn on extended debug
if (( $EXTENDED_DEBUG == 1 ))
then
    set -x
fi

get_base_settings

verbose_msg "Entering main loop.\n"

if [[ "$INITIAL_VACUUM" -eq 1 ]]
then
    verbose_msg "Initial vacuuming\n"
    $PSQL -q -A -t -X -c "VACUUM $TABLE_SCHEMA.$TABLE_NAME"
fi

verbose_msg "Current table size: %d pages.\n" "$CURRENT_PAGE_COUNT"

clean_block() {
   END_PAGE=$1
   BLOCK_PAGE=1
   i=0
   while [[ $i -lt $CLEAN_PAGES ]]
   do
      i=$(( $i + 1 ))
      PAGE_TO_WORK_ON=$(( $END_PAGE - $i ))
      BLOCK_PAGE=$(( $BLOCK_PAGE - 1 ))
      if [ $BLOCK_PAGE -eq 0 ]; then
         # Every $RA pages we do a clean of a lower page to fill the read ahead
         let CACHE_PAGE=$PAGE_TO_WORK_ON-$RA
         verbose_msg "Clean at $CACHE_PAGE to fill read ahead buffer\n"
         $PSQL -qAtXc "UPDATE $TABLE_SCHEMA.$TABLE_NAME SET $COLUMN_TO_UPDATE = $COLUMN_TO_UPDATE WHERE ctid = '($CACHE_PAGE,$ti)'::tid"
         BLOCK_PAGE=$RA
      fi
      let m=$i%50
      if [ $m -eq 0 ] ; then
         verbose_msg "Working on page %d (%d of %d)\n" "$PAGE_TO_WORK_ON" "$i" "$CLEAN_PAGES"
      fi
      clean_page $PAGE_TO_WORK_ON
      if [[ "$RETURN" != "ok" ]]
      then
          break
      fi
   done
}

# Run 4 parallel processes over different ranges, each CLEAN_PAGES in size
# Actually - this doesn't work as tuples get moved to pages from other processes.

let END_PAGE=$CURRENT_PAGE_COUNT
clean_block $END_PAGE &

#let END_PAGE=$END_PAGE-$CLEAN_PAGES
#clean_block $END_PAGE &

#let END_PAGE=$END_PAGE-$CLEAN_PAGES
#clean_block $END_PAGE &

#let END_PAGE=$END_PAGE-$CLEAN_PAGES
#clean_block $END_PAGE &

wait

if [[ "$FINAL_VACUUM" -eq 1 ]]
then
    verbose_msg "Final vacuuming\n"
    $PSQL -q -A -t -X -c "VACUUM VERBOSE $TABLE_SCHEMA.$TABLE_NAME"
fi

show_reindexation_sql

rm /tmp/$$.* >/dev/null 2>&1

verbose_msg "All done.\n"

