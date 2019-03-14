#!/bin/bash

DB='ilmenard'
DIR=`pwd`"/loaded/"

#load .shp files to Postgres DB
for FILE in *.shp
do
	printf "\n~~ loading $FILE to database $DB ~~\n\n"
	BASE=`basename $FILE .shp`
	shp2pgsql -s 4326 $BASE $BASE | psql -d $DB #filename followed by table name for DB
done

#move all files not matching .sh extension to "loaded" directory
for FILE in *.*
do
	[[ $FILE == *.sh ]] || [[ $FILE == *.sql ]] && continue
	printf "\n~~ moving $FILE to directory $DIR ~~\n"
	mv $FILE $DIR
done
