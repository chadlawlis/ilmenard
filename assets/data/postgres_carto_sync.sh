#!/bin/bash

#$1: PostgreSQL relation to sync to CARTO
#$2: CARTO table to sync with

CARTO='chadlawlis'
KEY=
HOST='localhost'
PORT='5432'
USER='postgres'
PW='postgres'
DB='ilmenard'

printf "\n~~ Synching * from $1 relation in $DB PostgreSQL DB into CARTO table $2 ~~\n\n"

#runs in "-append" mode by default
ogr2ogr \
	--config CARTODB_API_KEY $KEY \
	-t_srs EPSG:4326 \
	-nln $2 \
	-f CartoDB \
	"CartoDB:$CARTO" \
	PG:"host=$HOST
			port=$PORT
			user=$USER
			password=$PW
			dbname=$DB" \
	-sql "select * from $1"
