#!/bin/bash
#from http://jihedamine.blogspot.com/2008/02/automatically-changing-wallpaper.html
#crontab: * 4,8,16,19 * * * YOUR-HOME-FOLDER/.change.sh

HOUR=$(date +%H)
case "$HOUR" in
    04|05|06|07)
	gconftool -t string -s /desktop/gnome/background/picture_filename PATH-TO-SUNRISE-PICTURE
	;;
    08|09|10|11|12|13|14|15)
	gconftool -t string -s /desktop/gnome/background/picture_filename PATH-TO-DAY-PICTURE
	;;
    16|17|18 )
	gconftool -t string -s /desktop/gnome/background/picture_filename PATH-TO-SUNSET-PICTURE
	;;
    *)
	gconftool -t string -s /desktop/gnome/background/picture_filename PATH-TO-NIGHT-PICTURE
	;;
esac