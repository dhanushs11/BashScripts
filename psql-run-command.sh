#!/bin/bash


PORT=
DBNAME=
USERNAME=
DBHOSTNAME=
REGION=

# Set your RDS host
export RDSHOST="$DBHOSTNAME"

# Generate an authentication token using AWS CLI
export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port $PORT --region $REGION --username $USERNAME)"

# Connect to PostgreSQL using psql and run queries
psql "host=$RDSHOST port=$PORT sslmode=require user=$USERNAME dbname=$DBNAME password=$PGPASSWORD" <<EOF
EOF
