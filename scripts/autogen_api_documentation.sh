#!/bin/bash


DIRNAME=public/api_docs/

mkdir -p $DIRNAME

node node_modules/grape/scripts/extract_documentation.js api/ $DIRNAME/generated.xml >$DIRNAME/generated.log

xsltproc node_modules/grape/scripts/api_documentation_html.xsl $DIRNAME/generated.xml >$DIRNAME/index.html

