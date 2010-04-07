#!/bin/bash

DIR=$1
FORMAT=${2:-'pdf'}
FILENAME="hierarchy.$FORMAT"

TYPE="--java"
if [ -n "$3" ]; then
    if [ "$3" == "scala" ]; then
	TYPE="-a"
    fi
fi

cat \
  <(echo 'digraph types {') \
  <(ack-grep '(class|interface) \w+ (extends|implements) \w+' "$TYPE" -h -o $DIR |  \
    awk '{print "\"" $4 "\"", "->", "\"" $2 "\""}') \
  <(echo '}') #\
#  | dot -T$FORMAT >$FILENAME && okular $FILENAME
