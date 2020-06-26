#!/bin/bash

## Publish the notebooks

## Convert to html
jupyter nbconvert --to html covidPlots.ipynb
jupyter nbconvert --to html StateCountyPlots.ipynb

## Add the plotly line
sed -i bak '/<title>/a\
<script src="https:\/\/cdn.plot.ly\/plotly-latest.min.js"><\/script>' covidPlots.html

sed -i bak '/<title>/a\
<script src="https:\/\/cdn.plot.ly\/plotly-latest.min.js"><\/script>' StateCountyPlots.html

rm -f *.htmlbak

mv -f covidPlots.html ../docs/examples
mv -f StateCountyPlots.html ../docs/examples

echo 'HTML files are in ../docs/examples'
