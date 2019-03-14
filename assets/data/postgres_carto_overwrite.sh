#!/bin/bash

#$1: CARTO table to overwrite
#$2: PostgreSQL relation to overwrite with

CARTO='chadlawlis'
KEY=
HOST='localhost'
PORT='5432'
USER='postgres'
PW='postgres'
DB='ilmenard'

printf "\n~~ Overwriting CARTO table $1 with * from $2 relation in $DB PostgreSQL DB ~~\n\n"

ogr2ogr \
	--config CARTODB_API_KEY $KEY \
	-overwrite \
	-t_srs EPSG:4326 \
	-nln $1 \
	-f CartoDB \
	"CartoDB:$CARTO" \
	PG:"host=$HOST
			port=$PORT
			user=$USER
			password=$PW
			dbname=$DB" \
	-sql "select * from $2"
