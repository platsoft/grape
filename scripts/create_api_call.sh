#!/bin/bash

if [ $# -lt 3 ] ; then
	echo "Usage: $0 METHOD URL DBFUNCNAME INSTALL-DIR"
	exit;
fi

METHOD=$1
URL=$2
DBFUNCNAME=$3
BASEDIR=$4
JSFUNCNAME="api_`echo $URL | sed 's/[\/\:]*//g'`"

read -d '' apijs << EOF
"use strict";
var db;
exports = module.exports = function(app) {
	db = app.get('db');

/**
 * @desc
 * @method $method
 * @url $URL
`echo "$URL" | egrep -o '\:([a-z_]*)' | awk '{gsub(":", "", $1); print " * @param " $1 " INTEGER"}'`
 * @return JSON object 
 */
	app.${METHOD}("$URL", $JSFUNCNAME);
};

function $JSFUNCNAME(req, res)
{
	db.json_call("$DBFUNCNAME", {}, {response: res}); 
}

EOF

read -d '' dbfunc << EOF
CREATE OR REPLACE FUNCTION $DBFUNCNAME (JSON) RETURNS JSON AS \$\$
	ret JSON;
BEGIN

	RETURN ret;
END; \$\$ LANGUAGE plpgsql;

EOF

echo "Here follows the Node JS code for this API call: "
echo "=================="
echo "$apijs" 
echo "=================="
echo 
echo
echo "Here follows the SQL: "
echo "=================="
echo "$dbfunc"

