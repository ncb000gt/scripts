#!/bin/bash

DIR=$1
FORMAT=${2:-'pdf'}
FILENAME="hierarchy.$FORMAT"

cat \
  <(echo 'digraph types {') \
  <(ack '(class|interface) \w+ (extends|implements) \w+' --java -h -o $DIR |  \
    awk '{print "\"" $4 "\"", "->", "\"" $2 "\""}') \
  <(echo '}') \
  | dot -T$FORMAT >$FILENAME && open $FILENAME
