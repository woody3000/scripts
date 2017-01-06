#!/bin/bash
LAST_UPDATE_FILE=/home/koha/scripts/.`basename $0`.last_update

CURDATE=$(date)
echo "Started export at: $CURDATE"

SINCEDATE=$(date -d "25 hours ago")
if [[ -e $LAST_UPDATE_FILE ]];
then
        SINCEDATE=$(<$LAST_UPDATE_FILE)
        SINCEDATE=$(date -d "$SINCEDATE" +"%F %T")
fi

CURDATE_STR=`date +"%Y%m%d_%H%M%S"`

# script code

echo $CURDATE > $LAST_UPDATE_FILE
