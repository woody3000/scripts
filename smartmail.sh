#!/bin/bash
email=<email_address>
machine=<machine_name>
smart_data_dir=/root/smart_data
history_length=10

# check usage
usage()
{
   echo 'Usage: sh smartmail.sh <drive0> [drive1 [drive2...driveN]]'
   echo 'where <driveN> is the name of a device in /dev, e.g. ada0'
}

if [ $# -eq 0 ]
then
   usage
   exit 1
fi



chkdrive() {
    smartctl -n standby ${drivepath} 2>&1 > /dev/null
}

getRawLogs() {
  for drive in "$@"
  do
    drivepath=/dev/${drive}
    rawlog=${smart_data_dir}/${drive}/smart_raw_${drive}

    sleepcount=0

    chkdrive
    while [ $? != "0" ]
    do
      echo "Waiting for ${drivepath} to wake up..."
      sleep 60
      sleecount=`expr ${sleepcount} +1`
      chkdrive
    done

    # make sure the data directory exists
    if [ ! -d ${smart_data_dir}/${drive} ]; then mkdir -p ${smart_data_dir}/${drive}; fi

    # clean up any old raw log file
    truncate -s 0 ${rawlog}

    if [ ${sleepcount} -gt 0 ]
    then
      echo "DRIVE WAS ASLEEP FOR ROUGHLY ${sleepcount} MINUTES BEFORE STATUS WAS AVAILABLE" > ${rawlog}
    fi

    # write raw log data
    smartctl -H -A -l error -l selftest ${drivepath} >> ${rawlog}
  
  done
}

getSmartAttribute() {
  rawlog=$1
  smart_attr=$2
  retval=`grep "^[[:space:]]*$smart_attr" $rawlog  | tr -s " " | sed -e 's/^[[:space:]]*//' | cut -d " " -f 10`

  echo "$retval"
}

getOverallHealth() {
  retval=`grep "overall-health" $1  | tr -s " " | cut -d " " -f 6`
  echo "$retval"
}

getTemps() {
  retval=$( getSmartAttribute $1 194 )
  echo "$retval"
}

getReallocSectorCount() {
  retval=$( getSmartAttribute $1 5 )
  echo "$retval"
}

getPendingSectorCount() {
  retval=$( getSmartAttribute $1 197 )
  echo "$retval"
}

getUncorrectableSectorCount() {
  retval=$( getSmartAttribute $1 198 )
  echo "$retval"
}

getSleep() {
  retval=`grep "DRIVE WAS ASLEEP" $1 | cut -d' ' -f 6`
  echo "$retval"
}

rotateLog() {
  new_value=$1
  logfile=$2
  num_lines=$3

  tmpfile=`dirname $logfile`"/."`basename $logfile`
  echo ${new_value} > ${tmpfile}
  if [ ! -f ${logfile} ]; then touch ${logfile}; fi
  cat ${logfile} >> ${tmpfile}
  head -n $num_lines ${tmpfile} > ${logfile}
  rm ${tmpfile}
}

processLogs() {
  emailfile=$1
  shift

  # emit email header
  (
    echo "To: ${email}"
    echo "Subject: SMART Drive Status Summary for ${machine}"
    echo " "
    echo "Current SMART Results:"
    echo " "
  ) > ${emailfile}


  printf "%5s | %5s | %7s | %7s | %19s | %15s | %21s\n" "Drive" "Sleep" "Overall" "Temp(C)" "Reallocated Sectors" "Pending Sectors" "Uncorrectable Sectors" >> ${emailfile}
  printf "%97s\n" | tr " " "-" >> ${emailfile}

  for drive in "${@}"
  do
    overall_log=${smart_data_dir}/${drive}/overall_log
    temp_log=${smart_data_dir}/${drive}/temp_log
    realloc_log=${smart_data_dir}/${drive}/realloc_log
    pending_log=${smart_data_dir}/${drive}/pending_log
    uncorrectable_log=${smart_data_dir}/${drive}/uncorrectable_log

    sleep_time=$( getSleep ${smart_data_dir}/${drive}/smart_raw_${drive} )
    overall=$( getOverallHealth ${smart_data_dir}/${drive}/smart_raw_${drive} )
    temp=$( getTemps ${smart_data_dir}/${drive}/smart_raw_${drive} )
    realloc=$( getReallocSectorCount ${smart_data_dir}/${drive}/smart_raw_${drive} )
    pending=$( getPendingSectorCount ${smart_data_dir}/${drive}/smart_raw_${drive} )
    uncorrectable=$( getUncorrectableSectorCount ${smart_data_dir}/${drive}/smart_raw_${drive} )

    printf "%5s | %5s | %7s | %7s | %19s | %15s | %21s\n" "${drive}" "${sleep}" "${overall}" "${temp}" "${realloc}" "${pending}" "${uncorrectable}" >> ${emailfile}

    rotateLog $overall $overall_log $history_length
    rotateLog $temp $temp_log $history_length
    rotateLog $realloc $realloc_log $history_length
    rotateLog $pending $pending_log $history_length
    rotateLog $uncorrectable $uncorrectable_log $history_length
  done

  printf "%97s\n" | tr " " "-" >> ${emailfile}
  printf "\n\n" >> ${emailfile}

  for drive in "${@}"
  do
    printf "History for: $drive\n" >> ${emailfile}
    printf "%17s\n" | tr " " "-" >> ${emailfile}

    overall_lines=( `cat ${smart_data_dir}/${drive}/overall_log` )
    temp_lines=( `cat ${smart_data_dir}/${drive}/temp_log` )
    realloc_lines=( `cat ${smart_data_dir}/${drive}/realloc_log` )
    pending_lines=( `cat ${smart_data_dir}/${drive}/pending_log` )
    uncorrectable_lines=( `cat ${smart_data_dir}/${drive}/uncorrectable_log` )

    # find longest list
    hist_lengths=( ${#overall_lines[@]} ${#temp_lines[@]} ${#realloc_lines[@]} ${#pending_lines[@]} ${#uncorrectable_lines[@]} )
    max=${#overall_lines[@]}
    for i in "${hist_lengths[@]}"; do
      if [ $i -gt $max ];
      then
        max=$i
      fi
    done

    printf "%7s | %7s | %19s | %15s | %21s\n" "Overall" "Temp(C)" "Reallocated Sectors" "Pending Sectors" "Uncorrectable Sectors" >> ${emailfile}
    printf "%81s\n" | tr " " "-" >> ${emailfile}
    for ind in $(seq 0 $(( $max - 1 )) );
    do
      overall=${overall_lines[$ind]}
      temp=${temp_lines[$ind]}
      realloc=${realloc_lines[$ind]}
      pending=${pending_lines[$ind]}
      uncorrectable=${uncorrectable_lines[$ind]}
      printf "%7s | %7s | %19s | %15s | %21s\n" "${overall}" "${temp}" "${realloc}" "${pending}" "${uncorrectable}" >> ${emailfile}
    done

    printf "\n\n" >> ${emailfile}
  done
}

getRawLogs "$@"
processLogs /tmp/smart_email "$@"
sendmail -t < /tmp/smart_email
