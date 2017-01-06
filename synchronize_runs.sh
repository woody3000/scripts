#!/bin/bash
LOCK_DIR=/tmp/.`basename $0`.lock
PID_FILE=$LOCK_DIR/pid

if mkdir $LOCK_DIR 2> /dev/null;
then
        # spit our pid into the pid file
        echo $$ > "$PID_FILE"
else
        if [ -e  "$PID_FILE" ]
        then
                oldpid=$(<"$PID_FILE")
                if [ -e /proc/$oldpid ]
                then
                        # process still running, so silently quit
                        exit
                else
                        # process has died/finished without cleaning lock dir.
                        # presumably, safe to proceed
                        echo "Previous process has died/quit without cleaning lock dir."
                        echo "Presumably, it's safe to proceed"
                        echo $$ > "$PID_FILE"
                fi
        else
                echo "Cannot find pid file, therefore can't check if previous process is still running."
                echo "Please check for problems and if none found, delete $LOCK_DIR to proceed."
                exit
        fi
fi


# script code


rm -rf $LOCK_DIR
