#!/bin/bash

# ilmenard/assets/data/ directory
DATA=$(cd ../; pwd)

# unzip contents to ilmenard/assets/data/ directory
# -o maintains last modified date/time of the files inside the zip; -d specifies directory to extract to
for ZIP in $DATA/*.zip
do
	printf "\n~~ unzipping $ZIP ~~\n\n"
	unzip -o $ZIP -d $DATA
done

# review each .shp file via ogrinfo
# -al = all layers
# -so = summary only
for FILE in $DATA/*.shp
do
	printf "\n~~ review $FILE ~~\n\n"
	ogrinfo -al -so $FILE
done
