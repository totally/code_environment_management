#!/bin/bash

# Exit on failures
set -e 


USAGE="                                                                 \n
    Script to load a production-ish database to a development database  \n
    Should be run on host with access to backups.                       \n
                                                                        \n
    $0 <-e environment name> <-t code> <-l|-d>                          \n
                                                                        \n
    -e  environment name                                                \n
    -t  'code' is only supported type, currently                        \n
    -l  load database (can be used with -d option, to drop then load)   \n
    -d  drop database                                                   \n
                                                                        \n
    Example:                                                            \n
        $0 -e foo -t code -l    # Load database to foo environment      \n
        $0 -e foo -t code -d    # Drop database for foo environment     \n

                                                                        \n
"
send_usage() {
        echo -e $USAGE
}
error_usage() {
        echo -e $USAGE
        exit 1
}

USER=YOUR_MYSQL_USER
PASS=YOUR_MYSQL_PASS
DB_HOST=YOUR_MYSQL_HOST
APP=YOUR_APP_NAME

# Directories where dumps live (dumps should be on the localhost)
DUMP_DIR="/backups/${APP}_LOGICAL_BACKUP/latest"
SCHEMA_DIR="/backups/${APP}_SCHEMA_BACKUP/latest"

# Process command line opts
while getopts "ldhe:t:" OPTION
do
     case $OPTION in
         h)
             send_usage
             exit 1
             ;;
         l)
            LOAD_DB=true
            ;;
         d)
            DROP_DB=true
            ;;
         e)
            # Validate environment name is alphanumeric
            if [[ ! $OPTARG =~ ^[A-Za-z0-9]*$ ]]; then
                echo "ERROR: Environment name must be alphanumeric!"
                exit 1
            fi
             ENV=$OPTARG
             echo "Got environment: [$ENV]"
             ;;
         t)
            # code is only type supported, currently
            case $OPTARG in
            code)
                TYPE=$OPTARG
                echo "type is [$TYPE]"
                ;;
            *)
                echo "ERROR: Unknown type [$OPTARG]"
                exit 2
                ;;
            esac
            ;;
         ?)
             send_usage
             exit
             ;;
     esac
done

# ---------------
# SANITY CHECK
# ---------------
if [[ "$ENV" == "" ]]; then
    echo "ENV not set"
    error_usage
fi
if [[ "$TYPE" == "" ]]; then
    echo "TYPE not set"
    error_usage
fi

if [[ "$DROP_DB" != "true" ]] && [[ "$LOAD_DB" != "true" ]]; then
    echo "Please select either -l to load or -d to drop the database"
    error_usage
fi

# ---------------
# DB NAME
# ---------------
echo "TYPE is $TYPE"
if [ "$TYPE" == "code" ]
then
    DB=${APP}_${TYPE}_${ENV}
else
    echo "Cannot determine db for [$TYPE]"
    exit 1
fi

if [ "$DB" == "" ]
then
    echo "Invalid options. DB not found."
    exit 1
fi

echo "DB is [$DB]"

# Get backup files
PROD_DUMP=`find $DUMP_DIR -type f -name "${APP}*gz" | head -n1`
SCHEMA_DUMP=`find $SCHEMA_DIR -type f -name "${APP}*gz" | head -n1`

# Make sure dumps exist
if [ "$PROD_DUMP" == "" ]
then
    echo "PROD_DUMP not found"
    exit 1;
fi

if [ "$SCHEMA_DUMP" == "" ]
then
    echo "PROD_DUMP not found"
    exit 1;
fi

echo "production dump is [$PROD_DUMP]"
echo "schema dump is [$SCHEMA_DUMP]"

MYSQL_EXEC="mysql -p$PASS -u $USER -h $DB_HOST"

# DROP DB
if [ "$DROP_DB" == "true" ]
then
    echo "Dropping db [$DB]"
    echo "DROP DATABASE IF EXISTS $DB"       | $MYSQL_EXEC
fi

# LOAD DB
if [ "$LOAD_DB" == "true" ]
then
    echo "CREATING db [$DB]"
    echo "CREATE DATABASE IF NOT EXISTS $DB" | $MYSQL_EXEC
    echo "Restoring schema"
    gunzip -c $SCHEMA_DUMP                   | $MYSQL_EXEC $DB
    echo "Restoring data"
    gunzip -c $PROD_DUMP                     | $MYSQL_EXEC $DB
fi

