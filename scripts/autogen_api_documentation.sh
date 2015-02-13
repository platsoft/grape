#!/bin/bash

SCRIPTDIR=`dirname $0`


APIDIR=`find . -maxdepth 2 -type d -name api`
OUTPUTDIR=`find . -maxdepth 2 -type d -name public`

OUTPUTDIR="$OUTPUTDIR/api_docs"

echo "Reading source files from $APIDIR"
echo "Outputting to $OUTPUTDIR"

mkdir -p $OUTPUTDIR

node $SCRIPTDIR/extract_documentation.js $APIDIR/ $OUTPUTDIR/generated.xml >$OUTPUTDIR/generated.log

xsltproc $SCRIPTDIR/api_documentation_html.xsl $OUTPUTDIR/generated.xml >$OUTPUTDIR/index.html

cp $SCRIPTDIR/api_documentation_styles.css $OUTPUTDIR/styles.css


