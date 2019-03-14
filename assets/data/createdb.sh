#!/bin/bash

DB='ilmenard'

printf "\n~~ createdb $DB ~~\n"
createdb $DB

printf "\n~~ create extension postgis on DB $DB ~~\n\n"
psql -d $DB -c "create extension postgis;"

printf "\n~~ opening psql terminal in DB $DB ~~\n\n"
psql $DB
