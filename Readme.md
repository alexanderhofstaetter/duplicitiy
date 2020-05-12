# Duplicity Backup
A docker image for recurring [duplicity](http://duplicity.nongnu.org/) backups based on Ubuntu 20.04 and python3. It uses the latest version of duplicity (currently; `0.8.12`) including cron and the ability to define multiple duplicity backup tasks. Inspired by [ViViDboarder/docker-duplicity-cron](https://github.com/ViViDboarder/docker-duplicity-cron).

This image is also available on Docker Hub, see: (hub.docker.com/r/alexanderhofstaetter/duplicity)[https://hub.docker.com/r/alexanderhofstaetter/duplicity]. The `latest` tag gets built everytime a new push is made to the master branch.

**duplicity**
Duplicitiy is a backup tool which can perform full and incremental backups and stores them on different backends (e.g. S3, FTP, Public Clouds, Local, SCP) in tar format (compressed, signed/encrypted).

**Example**
```
duplicity full /home/me sftp://uid@other.host/some_dir
```

**Actions**
```
duplicity [full|incremental] [options] source_directory target_url
duplicity verify [options] [--compare-data] [--file-to-restore <relpath>] [--time time] source_url target_directory
duplicity collection-status [options] target_url
duplicity list-current-files [options] [--time time] target_url
duplicity [restore] [options] [--file-to-restore <relpath>] [--time time] source_url target_directory
duplicity remove-older-than <time> [options] [--force] target_url
duplicity remove-all-but-n-full <count> [options] [--force] target_url
duplicity remove-all-inc-of-but-n-full <count> [options] [--force] target_url
duplicity cleanup [options] [--force] [--extra-clean] target_url
```

## Instructions
Mount any directories you'd like to back up as a volume and run. You can define a backup task (and its schedule in cron style) via environment variables. One can also define multiple duplicity backup tasks.

## Environment Variables (Backup task)
| Variable | Default | Description |
| -------- | ------- | ----------- |
|BACKUP_NAME|backup|Unique name (used for name of lock file and duplicity cache directory to distinguish from other backup tasks). If multiple tasks should address the same backup (e.g. one task for full and inc backups; verify task for backup) these names must match. See examples folder in this repo.|
|BACKUP_SCHEDULE|0 0 * * *|Cron schedule for recurring task. If it is empty, the task can only be used together with `BACKUP_ON_START` for immediate execution after start.|
|BACKUP_ACTION||Defines the duplicity action parameter (See: [duplicity documenation](http://duplicity.nongnu.org/vers7/duplicity.1.html#sect4)). If none is specified, the first backup will be `full`, the following ones will be `inc`.|  
|BACKUP_SOURCE||Local path in the container which will be the source of the backup task (mount your data dir to this path).|
|BACKUP_DEST||Destination URL (duplicity <target_url>) to store backups (See [duplicity documenation](http://duplicity.nongnu.org/duplicity.1.html#sect7)).|
|BACKUP_ARGUMENTS||Specify duplicity CLI options (See [duplicity documenation](http://duplicity.nongnu.org/duplicity.1.html#sect5)).|
|BACKUP_DEFAULT_ARGUMENTS||same as `BACKUP_ARGUMENTS` but applies to all defined backup tasks (see below)|
|BACKUP_SCRIPTS_BEFORE|/scripts/before/*|Scripts directory which will be executed before the backup task.|
|BACKUP_SCRIPTS_AFTER|/scripts/after/*|Scripts directory which will be executed after the backup task.|
|FLOCK_WAIT|60|Seconds to wait for a lock before skipping a backup|
|BACKUP_ON_START|false|If set to `true` the defined backup task will run immediately after start / init.|


## Environment Variables (duplicity)
| Variable | Default | Description |
| -------- | ------- | ----------- |
|AWS_ACCESS_KEY_ID| |Required for writing to S3|
|AWS_DEFAULT_REGION| |Required for writing to S3|
|AWS_SECRET_ACCESS_KEY| |Required for writing to S3|
|FTP_PASSWORD||Used to provide passwords for some backends. May not work without an attached TTY. Supported by most backends which are password capable. More secure than setting it in the backend url (which might be readable in the operating systems process listing to other users on the same machine).|
|PASSPHRASE||This passphrase is passed to GnuPG. If this is not set, the user will be prompted for the passphrase.|

## Defining multiple backup tasks
If you want to define multiple duplicity backup tasks within one container, you can add numbers (e.g. **\_1\_**) to all backup task-related environment variables. You can define multiple tasks where every task has its own set of environment variables (inherited from the global environment variables)

The schedule of every task gets added to the `/crontab.conf` file

**Example**

```
PASSPHRASE=SECRET_PASSWORD_HERE

BACKUP_1_NAME=backup1
BACKUP_1_ACTION=full
BACKUP_1_SCHEDULE=0 2 * * *
BACKUP_1_SOURCE=/data/sourcedir_one
BACKUP_1_DEST=boto3+s3://my-aws-s3-bucket-name/backups
BACKUP_1_ARGUMENTS= --s3-use-deep-archive --volsize=5000 

BACKUP_2_NAME=backup2
BACKUP_2_ACTION=full
BACKUP_2_SCHEDULE=0 3 * * *
BACKUP_2_SOURCE=/data/sourcedir_two
BACKUP_2_DEST=sftp://username@server.example.org/Backups
BACKUP_2_ARGUMENTS= --volsize=1000 
```

This example defines two backup tasks (everyday at 2am and 3am, where one backup task is stored in S3 (source: `/data/sourcedir_one`) and the other one uses the SFTP server as backup destination). Both backup tasks will be encrypted with the same `PASSPHRASE` (here: *SECRET_PASSWORD_HERE2*)

**Custom environment variables per task**

```
PASSPHRASE=ANOTHER_SECRET_PASSWORD_HERE2

BACKUP_1_NAME=backup1
BACKUP_1_ACTION=full
BACKUP_1_SCHEDULE=0 2 * * *
BACKUP_1_SOURCE=/data/sourcedir_one
BACKUP_1_DEST=boto3+s3://my-aws-s3-bucket-name/backups
BACKUP_1_ARGUMENTS= --s3-use-deep-archive --volsize=5000 
BACKUP_1_ENV_PASSPHRASE=Foo11Bar

BACKUP_2_NAME=backup2
BACKUP_2_ACTION=full
BACKUP_2_SCHEDULE=0 3 * * *
BACKUP_2_SOURCE=/data/sourcedir_two
BACKUP_2_DEST=sftp://username@server.example.org/Backups
BACKUP_2_ARGUMENTS= --volsize=1000 
BACKUP_2_ENV_PASSPHRASE=Foo22Bar
BACKUP_2_ENV_SIGN_PASSPHRASE=Foo22BarSignExample

```

In this example every backup task has its own `PASSPHRASE` environment variable. For every backup task you can set a dedicated set of env variables. Simple prefix the variable with `BACKUP_1_ENV_` (where 1 is the number of your backup task) and the script will crop the prefix and pass the specified variable to duplicity. In this example the global `PASSPHRASE` variable is not effectivly used (because it gets overwritten in every task) - if backup2 would not specify `BACKUP_2_ENV_PASSPHRASE` then backup2 would be encrypted with the global `PASSPHRASE` variable (inheritance).

**Specific duplicity arguments per task**
The same applies to the duplicity CLI arguments. With `BACKUP_DEFAULT_ARGUMENTS` you can define CLI arguments used in every task (in every duplicity CLI call) and with `BACKUP_<number>_ARGUMENTS` you can specify arguments for this specific task.

## Encryption
By default duplicity will use a symmetric encryption using just your passphrase. If you wish to use a GPG key, you can add a ro mount to your `~/.gnupg` directory and then provide the `--encrypt-key <key-id>` option in `BACKUP_ARGUMENTS`. The key will be used to sign and encrypt your files before sending to the backup destination.

Need to generate a key? Install `gnupg` and run `gnupg --gen-key`

## Backup immediately on container start
You can set the variable `BACKUP_ON_START` to `true` if you want the backup to start immediately after the container starts. This only applies to the "default" task (not to numbered tasks).

## Tips

### Missing dependencies?
Please file a ticket! Duplicity supports a ton of backends and I haven't had a chance to validate that all dependencies are present in the image. If something is missing, let me know and I'll add it.

### Getting complains about no terminal for askpass?
Instead of using `FTP_PASSWORD`, add the password to the endpoint url.

### Backup to multiple destinations (e.g. S3+SFTP)
Specifiy a "multi" target with: `multi:///multi.json?mode=mirror&onfail=continue` and mount your json file to `/multi.json` in the container. See [duplicity documenation](http://duplicity.nongnu.org/duplicity.1.html#sect20) for different options and examples.

### Backing up from another container
Mount all volumes from your existing container and then back up by providing the paths to those volumes. If there are more than one volumes, you'll want to define multiple backup tasks or mount them into several subdirectories and backup the whole (parent) directory.

### Restoring a backup
Simple run a task with the `restore` action and with an empty `BACKUP_SOURCE` variable. Alternative you can execute the restore command directly in the container. Make sure all the options used for the original backup task are used on restore too (e.g custom prefix names).

```
docker exec duplicity duplicity restore --name $BACKUP_NAME $BACKUP_ARGUMENTS $BACKUP_DEST
```

## Docker-compose
You can use this image via docker-compose. Simply create two files in the same directory, a `docker-compose.yml` and a `.env` file.

**docker-compose.yml**
```
version: "3.7"
services:
  duplicity:
    image: alexanderhofstaetter/duplicity
    container_name: duplicity
    hostname: duplicity
    restart: always
    env_file:
      - .env
    volumes:
      - cache:/root/.cache/duplicity
    #  - ./config/known_hosts:/root/.ssh/known_hosts:ro
volumes:
  cache:
```

**.env**
```
TZ=Europe/Vienna

BACKUP_ON_START=false
BACKUP_DEFAULT_ARGUMENTS=--allow-source-mismatch --s3-use-deep-archive --volsize=1000 --exclude-other-filesystems

BACKUP_1_NAME=backup1
BACKUP_1_ACTION=full
BACKUP_1_SCHEDULE=0 2 * * *
BACKUP_1_SOURCE=/data/sourcedir1
BACKUP_1_DEST=boto3+s3://my-aws-s3-bucket-name/backups
BACKUP_1_ARGUMENTS=
BACKUP_1_ENV_PASSPHRASE=SECRET_PASSWORD_HERE1!

BACKUP_2_NAME=backup2
BACKUP_2_ACTION=full
BACKUP_2_SCHEDULE=0 3 * * *
BACKUP_2_SOURCE=/data/sourcedir2
BACKUP_2_DEST=sftp://username@server.example.org/Backups
BACKUP_2_ARGUMENTS=
BACKUP_1_ENV_PASSPHRASE=ANOTHER_SECRET_PASSWORD_HERE2"
```
