#!/bin/bash
#
# Change an active parameter to a new value. Does not work
# if the parameter does not exist in the config file or
# if it has been commented out.

#. ~/.bash_profile

if [ $# -ne 2 ] ; then
   echo "Usage: $0 <PARAMETER> <VALUE>"
   exit 1
fi

PARM=$1
VALUE=$2

PGCONF=$PGDATA/postgresql.conf
if [ -f "$PGCONF" ] ; then
  cat $PGCONF | sed "s/^[# \t]*\($PARM[ \t]*=[ \t]*\).*$/\1$VALUE/" > $PGCONF.2
  mv $PGCONF.2 $PGCONF
  pg_ctl status -D $PGDATA > /dev/null 2>&1 && pg_ctl reload -D $PGDATA
fi

