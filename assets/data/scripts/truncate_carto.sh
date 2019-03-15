#!/bin/bash

# $1 = CARTO table to truncate

# CARTO username
CARTO='chadlawlis'
# CARTO API Key
KEY=
# TRUNCATE TABLE SQL for API call
SQL=`echo "TRUNCATE TABLE $1" | tr ' ' +` # convert spaces in SQL query ' ' to '+' for API call

printf "\n~~ TRUNCATE CARTO table $1 ~~\n\n"

# Execute the API call
curl "https://$CARTO.carto.com/api/v2/sql?api_key=${KEY}&q=${SQL}"
