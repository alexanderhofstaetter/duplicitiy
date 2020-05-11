#! /bin/bash

ENV=$2
ID=$3
LOG=/cron.log
HEALTH_FILE=/unhealthy

touch $ENV
source $ENV

# Execute command and write output to log
$@ $ID 2>> $LOG && rm -f $HEALTH_FILE || { touch $HEALTH_FILE; exit 1; }
