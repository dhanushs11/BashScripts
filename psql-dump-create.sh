#!/bin/bash
current_date=$(date +"%d-%b-%Y")
PORT=''
DBNAME=''
USERNAME=''
DBHOSTNAME=''
REGION=''
export RDSHOST="$DBHOSTNAME"

export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port $PORT --region $REGION --username $USERNAME)"

pg_dump "host=$RDSHOST port=$PORT sslmode=require dbname=$DBNAME user=$USERNAME password=$PGPASSWORD" > "${current_date}-${DBNAME}-dump.sql"