#!/bin/bash

for ZIP in *.zip
do
	printf "\n~~ unzipping $ZIP ~~\n\n"
	unzip -o $ZIP #-o maintains last modified time of the files inside the zip
done

for FILE in *.shp
do
	printf "\n~~ review $FILE ~~\n\n"
	ogrinfo -al -so $FILE
done
