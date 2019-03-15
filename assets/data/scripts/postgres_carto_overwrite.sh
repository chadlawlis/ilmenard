#!/bin/bash

# $1 = parameter; CARTO table to overwrite
# $2 = parameter; Postgres relation to overwrite with

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

printf "\n~~ Overwriting CARTO table $1 with * from $2 relation in $DB Postgres DB ~~\n\n"

# CARTO driver has been updated, available since GDAL 1.11, but does not seem to be available in my 2.1.1 installation
# https://www.gdal.org/drv_carto.html
ogr2ogr \
	--config CARTODB_API_KEY $KEY \ # "CARTO_API_KEY" with new driver
	-overwrite \ # runs in "-append" mode by default; running in "-overwrite" mode here
	-t_srs EPSG:4326 \
	-nln $1 \
	-f CartoDB \ # "Carto" with new driver
	"CartoDB:$CARTO" \ # "Carto:" with new driver
	PG:"host=$HOST
			port=$PORT
			user=$USER
			password=$PW
			dbname=$DB" \
	-sql "select * from $2"
