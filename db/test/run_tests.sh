#!/bin/bash

SCRIPT="`readlink -e $0`"
SCRIPTPATH="`dirname $SCRIPT`"

for i in `ls $SCRIPTPATH/*sql` ; do
	SQLFILE="$i"
	EXPECTEDFILE="`basename "$SQLFILE" .sql`.expected"
	RESULTFILE="`basename "$SQLFILE" .sql`.result"
	if [ -f "$SCRIPTPATH/$EXPECTEDFILE" ] ; then
		echo -n "Running ${SQLFILE}..."
		cat "$SQLFILE" | psql -At raisin raisin >"$RESULTFILE"
		colordiff "$RESULTFILE" "$EXPECTEDFILE"
		if [ "$?" = "0" ] ; then
			echo -e "\E[0;32mOK\E[0m"
		fi
	fi
done


