#! /bin/bash

set -e
(

	if [ -z "$BACKUP_DEST" ]; then
        echo 'ERROR: No BACKUP_DEST (duplicity: <url>) specified. Set your environment variable.'
        exit 1
    fi
    
    if ! flock -x -w $FLOCK_WAIT 200 ; then
        echo 'ERROR: Could not obtain lock. Exiting.'
        exit 1
    fi

    # Run pre scripts
    for file in $BACKUP_SCRIPTS_BEFORE; do
	    [ -f "$file" ] && [ -x "$file" ] && "$file"
	done
    
    duplicity \
        $BACKUP_ACTION \
        --asynchronous-upload \
        --log-file /root/duplicity.log \
        --name $BACKUP_NAME \
        $BACKUP_DEFAULT_ARGUMENTS \
        $BACKUP_ARGUMENTS \
        $BACKUP_SOURCE \
        $BACKUP_DEST

    # Run post scripts
    for file in $BACKUP_SCRIPTS_AFTER; do
	    [ -f "$file" ] && [ -x "$file" ] && "$file"
	done

) 200>/var/lock/duplicity/.duplicity$BACKUP_NAME.lock

