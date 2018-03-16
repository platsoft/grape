#!/bin/bash

json=`cat config.json`
DBURI=`node -e "var c=$json;console.log(c.dburi);"`

setup_database -r -d "$DBURI" ../db/schema/ ../db/function/ ../db/data/ db/


