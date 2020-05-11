FROM ubuntu:20.04
LABEL maintainer="alex@hofstaetter.io"

ARG DEBIAN_FRONTEND=noninteractive

# Update and upgrade
RUN apt-get update -y && apt-get upgrade -y && apt-get remove -y && \
	\
	# Installing pre-requisites \
	apt-get install -y \
        build-essential \
        bzr \
        cron \
        tzdata \
        intltool \
        lftp \
        openssl \
        par2 \
        librsync-dev \
        python3-pip \
        python3-dev \
        python3-future \
        rdiff \
        wget && \
	apt-get remove -y && \
	rm -rf /var/lib/apt/* && \
	\
	# Download and Install duplicity \
	wget https://code.launchpad.net/duplicity/0.8-series/0.8.12/+download/duplicity-0.8.12.1612.tar.gz && \
    tar xaf duplicity-*.tar.gz && \
    cd duplicity-*/ && \
    pip3 install --requirement requirements.txt --no-cache-dir && \
    pip3 install boto boto3 --no-cache-dir && \
    \
	# Needed for S3 Glacier to make restart of backups possible \
	# Patch function, see: https://bugs.launchpad.net/duplicity/+bug/1875937 \
	sed -i '/validate_encryption_settings(globals.restart.last_backup, mf)/s/^/#/g' duplicity/dup_main.py && \
	\
	# Finally run setup and install \
	python3 setup.py install && \
	cd ../ && rm -rf duplicity-*

VOLUME /var/lock/duplicity
VOLUME /root/.cache/duplicity

ENV BACKUP_NAME backup
ENV BACKUP_SCHEDULE 0 0 * * *
ENV BACKUP_ACTION ""
ENV BACKUP_SOURCE ""
ENV BACKUP_DEST ""
ENV BACKUP_ARGUMENTS ""
ENV BACKUP_SCRIPTS_BEFORE /scripts/before/*
ENV BACKUP_SCRIPTS_AFTER /scripts/after/*
ENV BACKUP_ON_START false
ENV FLOCK_WAIT 60

# Create pre backup and post backup script directories
RUN mkdir -p /scripts/before && mkdir -p /scripts/after

# Copy application scripts 
COPY scripts /scripts

RUN ["chmod", "-R", "+x", "/scripts"]

CMD ["/scripts/entrypoint.sh"]


# Labels
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="alexanderhofstaetter/duplicity"
LABEL org.label-schema.description="Simple duplicity backups"
LABEL org.label-schema.vcs-url="https://github.com/alexanderhofstaetter/duplicity"