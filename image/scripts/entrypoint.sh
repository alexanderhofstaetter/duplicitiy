#! /bin/bash

# If key id is provided add arg
# if [ -e "$GPG_KEY_ID" ]; then
#     export OPT_ARGUMENTS="$OPT_ARGUMENTS --encrypt-sign-key=\"$GPG_KEY_ID\""
# fi

# Export the current environment to a file so it can be loaded again
mkdir -p /env
export -p > /env/default.sh

# Remove some vars we don't want to keep
sed -i '/\(HOSTNAME\|affinity\|LS_COLORS\|TERM\|SHLVL\|PWD\)/d' /env/default.sh

# Use bash for cron
echo "SHELL=/bin/bash" > /crontab.conf

if [ -n "$BACKUP_SCHEDULE" ] && [ -n "$BACKUP_DEST" ]; then
    echo "$BACKUP_SCHEDULE /scripts/execute.sh /scripts/duplicity.sh /env/default.sh" >> /crontab.conf
    echo "Backups scheduled as $BACKUP_SCHEDULE"
fi

# Get all backup job numbers
backup_jobs=($(compgen -A variable | grep -oP 'BACKUP_([[:digit:]]{1,})_' | sed 's/[^0-9]//g' | sort -n | awk '!seen[$0]++'))

# set the correct environment variables for each backup job
for i in "${backup_jobs[@]}"
do
	cp /env/default.sh /env/job-$i.sh 	# create own file for each job
	
	env_vars=($(compgen -A variable | grep -P "BACKUP_${i}_.*"))
	
	for new_var_name in "${env_vars[@]}"
	do
		var_name=${new_var_name//${i}_}
		sed -i "/\b${var_name}\b/d" /env/job-$i.sh
		sed -i "s/\b${new_var_name}\b/${var_name}/g" /env/job-$i.sh
		
		if [[ $var_name == BACKUP_ENV_* ]]; then
			env=($(echo ${var_name} | sed -e "s/^BACKUP_ENV_//"))
			sed -i "/\b${env}\b/d" /env/job-$i.sh
			sed -i "s/\b${var_name}\b/${env}/g" /env/job-$i.sh
		fi
	done
	sed -i "/\bBACKUP_[[:digit:]]\+_/d" /env/job-$i.sh	# delete all other numbered env vars
		
	schedule_env_var_name="BACKUP_${i}_SCHEDULE"

	if [ -n "${!schedule_env_var_name}" ]; then
		# cron schedule set for this job
		echo "${!schedule_env_var_name} /scripts/execute.sh /scripts/duplicity.sh /env/job-$i.sh $i" >> /crontab.conf
    	echo "Backups scheduled as ${!schedule_env_var_name}"
    	
    elif [ -n "$BACKUP_SCHEDULE" ]; then
    	# if not use default cron schedule
    	echo "$BACKUP_SCHEDULE /scripts/execute.sh /scripts/duplicity.sh /env/job-$i.sh $i" >> /crontab.conf
    	echo "Backups scheduled as $BACKUP_SCHEDULE"
    	
	fi

done

sed -i "/\bBACKUP_[[:digit:]]\+_/d" /env/default.sh		# delete all numbered env vars from default env file

# Add to crontab
crontab /crontab.conf

echo "Starting duplicity cron..."
cron

# If defined explicitly, take a backup on startup
if [ "$BACKUP_ON_START" == "true" ]; then
    echo "Executing backup on start ..."
    /scripts/execute.sh /scripts/duplicity.sh /env/default.sh
fi

touch /cron.log /root/duplicity.log
tail -f /cron.log /root/duplicity.log
