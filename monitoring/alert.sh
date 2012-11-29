#from http://kimiensoftware.com/software/downloads

SUBJECT=$1
BODY=$2
TEXT=$3		# 1 to enable text mode
TO=$4

if [ "$TO" = "" ] ; then
   TO=<EMAIL FOR ALERT RECIPIENTS>
fi

if [ -f "$BODY" ] ; then
   BODY=`cat $BODY`
fi

if [ "$TEXT" = "" ] ; then

(
echo "From: postgres@localhost.localdomain "
echo "To: $TO "
echo "MIME-Version: 1.0"
echo "Content-Type: multipart/alternative; " 
echo ' boundary="ENDDDD"' 
echo "Subject: $SUBJECT" 
echo "" 
echo "This is a MIME-encapsulated message" 
echo "" 
echo "--ENDDDD" 
echo "Content-Type: text/html" 
echo "" 
echo "$BODY"
echo "--ENDDDD"
) | /usr/sbin/sendmail -t

else

(
echo "From: postgres@localhost.localdomain "
echo "To: $TO "
echo "Subject: $SUBJECT"
echo ""
echo "$BODY"
) | /usr/sbin/sendmail -t

fi
