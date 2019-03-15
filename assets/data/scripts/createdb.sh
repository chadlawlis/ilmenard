#!/bin/bash

# Postgres database to load to
DB='ilmenard'

# create database
printf "\n~~ createdb $DB ~~\n"
createdb $DB

# create PostGIS extension
printf "\n~~ create extension postgis on DB $DB ~~\n\n"
psql -d $DB -c "create extension postgis;"

# open psql terminal in database
printf "\n~~ opening psql terminal in DB $DB ~~\n\n"
psql $DB
