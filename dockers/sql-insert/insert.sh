#!/bin/bash

echo "Getting SQl to import from url"
curl -o /db/importing.sql $MYSQL_DATAFILE_URL




echo "Waiting mysql on 3305..."

while ! nc -z $MYSQL_HOST 3306; do   
  sleep 2 # wait for 1/10 of the second before check again
done

#Wait so all is ready
sleep 5

echo "Adding sql to mysql server"
if ! mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "use ${MYSQL_DATABASE}"; then
  echo "No database on server creating"
  echo "Creating database ${MYSQL_DATABASE}"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "create database ${MYSQL_DATABASE}"
  NEW_USER="CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"
  GRANT_PRIVILEGES="GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;"

  echo "Creating user ${MYSQL_USER}"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "${NEW_USER}"
  echo "Granting privileges to user ${MYSQL_USER}"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "${GRANT_PRIVILEGES}"

  echo "Flushing privileges"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
  
  echo "Adding datasource"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD < /db/importing.sql

  echo "Database created"

fi
  echo "We already have the database"