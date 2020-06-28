#!/bin/bash

## Publish the notebooks
## Use -e to execute

execute=""

if [ $# -gt 0 ]
then
    if [ "$1" == "-e" ]
    then
       execute="--execute"
    fi
fi

## Convert to html
jupyter nbconvert --to html $execute covidPlots.ipynb
jupyter nbconvert --to html $execute StateCountyPlots.ipynb

## Add the plotly line
sed -i bak '/<title>/a\
<script src="https:\/\/cdn.plot.ly\/plotly-latest.min.js"><\/script>' covidPlots.html

sed -i bak '/<title>/a\
<script src="https:\/\/cdn.plot.ly\/plotly-latest.min.js"><\/script>' StateCountyPlots.html

rm -f *.htmlbak

mv -f covidPlots.html ../docs/examples
mv -f StateCountyPlots.html ../docs/examples

d=$(date)

sed "s/__DATE__/$d/" ../docs/index.html_template > ../docs/index.html

echo 'HTML files are in ../docs/examples'
