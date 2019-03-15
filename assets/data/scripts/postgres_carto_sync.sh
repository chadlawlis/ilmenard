#!/bin/bash

# $1 = parameter; Postgres relation to sync to CARTO
# $2 = parameter; CARTO table to sync with

# CARTO username
CARTO='chadlawlis'
# CARTO API Key
KEY=
# Postgres host
HOST='localhost'
# Postgres host port
PORT='5432'
# Postgres username
USER='postgres'
# Postgres password
PW='postgres'
# Postgres database
DB='ilmenard'

printf "\n~~ Synching * from $1 relation in $DB Postgres DB into CARTO table $2 ~~\n\n"

# CARTO driver has been updated, available since GDAL 1.11, but does not seem to be available in my 2.1.1 installation
# https://www.gdal.org/drv_carto.html
ogr2ogr \ # ogr2ogr runs in "-append" mode by default; will append records synched to a table with existing records
	--config CARTODB_API_KEY $KEY \ # "CARTO_API_KEY" with new driver
	-t_srs EPSG:4326 \
	-nln $2 \
	-f CartoDB \ # "Carto" with new driver
	"CartoDB:$CARTO" \ # "Carto:" with new driver
	PG:"host=$HOST
			port=$PORT
			user=$USER
			password=$PW
			dbname=$DB" \
	-sql "select * from $1"
