#!/bin/bash

# Postgres database to load to
DB='ilmenard'
# ilmenard/assets/data/ directory
DATA=$(cd ..; pwd)"/"
# ilmenard/assets/data/loaded/ directory
LOADED=$(cd ../loaded; pwd)"/"

# load all .shp files (assuming EPSG:4326) in ilmenard/assets/data/ directory to Postgres database
for FILE in $DATA*.shp
do
	printf "\n~~ loading $FILE to database $DB ~~\n\n"
	BASE=`basename $FILE .shp`
	shp2pgsql -s 4326 $FILE $BASE | psql -d $DB # filename followed by basename of file for table name in database
done

# move all files not matching .sh or .sql extension to ilmenard/assets/data/loaded/ directory
for FILE in $DATA*.*
do
	[[ $FILE == *.sh ]] || [[ $FILE == *.sql ]] && continue
	printf "\n~~ moving $FILE to directory $LOADED ~~\n"
	mv $FILE $LOADED
done
