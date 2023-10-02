#!/bin/bash
echo "Adding sql to mysql server"
if ! mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "use ${MYSQL_DATABASE}"; then
  echo "No database on server creating"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "create database ${MYSQL_DATABASE}"
  NEW_USER="CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"
  GRANT_PRIVILEGES="GRANT ALL PRIVILEGES ON '${MYSQL_USER}'.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "${NEW_USER} ${GRANT_PRIVILEGES}"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
  echo "Adding datasource"
  mysql -h $MYSQL_HOST -u root -p$MYSQL_ROOT_PASSWORD < /db/$MYSQL_DATAFILE.sql

fi
  echo "We already have the database"