# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:percent
#     text_representation:
#       extension: .jl
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.4.2
#   kernelspec:
#     display_name: Julia dataAnalysis 1.4.2
#     language: julia
#     name: julia-dataanalysis-1.4
# ---

# %% [markdown]
# <span style="font-size:3em;">Covid 19 Plots</span>
#
# Note that you can manipulate the plots. You can...
#
# * Single click on a label in the legend (e.g. "US") to remove that line from the plot (single click again to bring it back)
# * Double click on a label in the legend (e.g. "US") to only show that line in the plot (double click again to bring back the others)
# * Hover over a line to see its value at that point. You can change what you see. Clicking on the top row third icon from the right will show a single value for the line closest to your pointer [this is useful]. Clicking on the top row second icon from the right will show all values (the default). 

# %% tags=[]
using Covid19    # My package under development
using DataFrames, DataFramesMeta
using Lazy: @>

# %% [markdown]
# # Get Covid19 data
#
# Update to the latest data

# %%
updateJhuCSSE()

# %% [markdown]
# Get the confirmed global cases dataset

# %%
confirmedCases = getCovid19Data(ConfirmedCases, CountryLevel, 30);  # Start when at least 30 cases

# %% [markdown]
# What's the last date we have?

# %%
nrow(confirmedCases)

# %%
maximum(confirmedCases.Date)

# %% [markdown]
# # US cases

# %%
confirmedCasesUS = @where(confirmedCases, :Country_Region .== "US", :daysSince .>= 3);

# %%
using Plots          # Note that currently we need RecipesPipeline#master so that we get correct group sorting (pull request #59)
using StatsPlots
using Format
plotlyjs(size=(700,400))

# Format numbers with commas
fc(x) = format(x, commas=true, precision=0)

# %% [markdown]
# Total # of cases (left is linear, right is log)

# %%
p = @df confirmedCasesUS plot(:daysSince, :Value_rolling7, xaxis="Days since 30 cases first recorded",
                            yaxis="Total number of cases", yformatter=fc,
                            title="Total Covid-19 cases by day in US (7 day rolling average)",
                            label=nothing, linewidth=3)

# %%
savefig(p, "bla.html")

# %%
@df confirmedCasesUS plot(:daysSince, :Value_rolling7, xaxis="Days since 30 cases first recorded",
                            yaxis="Total number of cases (log)", yformatter=fc, 
                            yscale=:log10,
                            title="Total Covid-19 cases by day in US (7 day rolling average) (semi-log)",
                            label=nothing, linewidth=3)

# %% [markdown]
# Number of new cases

# %%
@df confirmedCasesUS plot(:daysSince, :Value_new_rolling7, xaxis="Days since 30 cases first recorded",
                            yaxis="NEW cases", yformatter=fc,
                            title="New Covid-19 cases by day in US (7 day rolling average)",
                            label=nothing, linewidth=3)

# %% [markdown]
# ## Compare rolling average to raw data

# %% [markdown]
# Let's try to reproduce a New York Times plot - comparing a rolling average to the actual values

# %% [markdown]
# A function to do the actual with 7 day rolling average

# %%
function plotActualAnd7DayAvg(df, value::Symbol, valueRolling7::Symbol, ylab, ylog=false, legend=:topright)
    @df df plot(:Date, df[!, value], linewidth=3, yformatter=fc, yminorticks=true, xrotation=45, 
                              label=ylab, yscale= ylog ? :log10 : :identity, legend=legend,
                              yaxis=ylab)
    @df df plot!(:Date, df[!, valueRolling7], linewidth=3, label="7 day rolling average")
end

# %%
plotActualAnd7DayAvg(confirmedCasesUS, :Value_new, :Value_new_rolling7, "New cases per day")

# %%
plotActualAnd7DayAvg(confirmedCasesUS, :Value_new, :Value_new_rolling7, "New cases per day (log)", true, :right)

# %% [markdown]
# How many cases are there?

# %%
plotActualAnd7DayAvg(confirmedCasesUS, :Value, :Value_rolling7, "Total cases", false, :right)

# %%
plotActualAnd7DayAvg(confirmedCasesUS, :Value, :Value_rolling7, 
                     "Total cases (log)", true, :right)

# %% [markdown]
# ## Compare US to EU
#
# The following replicates a plot shown on CNN comparing US and EU new cases
# See https://sanjuanislander.com/news-articles/31295/a-sobering-chart-eu-vs-usa-statistics-of-confirmed-covid-cases
# The countries aren't all of the ones in the EU, but seem to be the largest contributors. 

# %%
eu = ["France", "Germany", "Italy", "United Kingdom", "Spain", "Switzerland", "Austria", "Portugal"]
confirmedCasesEU = @where(confirmedCases, in.(:Country_Region, [eu]), :daysSince .>= 3)
confirmedCasesEU = combine(groupby(confirmedCasesEU, :Date), [:Value_new_rolling7] => sum => :Value_new_rolling7);

# %%
@df confirmedCasesUS plot(:Date, :Value_new_rolling7, label="US", lw=3, legend=:right)
@df confirmedCasesEU plot!(:Date, :Value_new_rolling7, yformatter=fc, xrotation=45, label="EU", lw=3)
plot!(title="New cases per day US vs. EU", ylab="# of new cases per day (7 day avg)")

# %% [markdown]
# # Top global cases

# %% [markdown]
# Find the countries with the most cases.

# %%
function topCountries(df::DataFrame, n::Int)
    tc = @> begin    # Construct a pipeline
        df   
        sort( [:Date, :Value], rev=(true, true))
        first(n)                 # Get the n largest
        getindex(:, :Country_Region)   # Pull out the country/region name
    end
    String.(tc)
end

# %%
categorical!(confirmedCases, :Country_Region);

# %%
topCountriesCases = topCountries(confirmedCases, 10);
push!(topCountriesCases, "Sweden");  # Let's include Sweden to see how they compare

# %%
confirmedCasesTop = @where(confirmedCases, in.(:Country_Region, [topCountriesCases]), :Value_new .> 0);

# %%
levels!(confirmedCasesTop.Country_Region, topCountriesCases)
droplevels!(confirmedCasesTop.Country_Region);
ordered!(confirmedCasesTop.Country_Region, true);

# %%
levels(confirmedCasesTop.Country_Region)

# %% [markdown]
# Plot the cases

# %%
lw = fill(2, (1,length(topCountriesCases))); lw[1] = 5;

# %%
@df confirmedCasesTop plot(:daysSince, :Value_new_rolling7, group=:Country_Region,
                           yscale=:log10, yformatter=fc, yminorticks=true, legend=:right, lw=lw,
                           xaxis="Days since 30 cases reported", yaxis="New cases per day (log)",
                           xlimit=(0, maximum(:daysSince)*1.3),
                           title="New Covid-19 cases per day (7 day rolling average) (semi-log)")

# %% [markdown]
# Let's not include China to have everything on a reasonable scale

# %% [markdown]
# Plot trajectory like https://aatishb.com/covidtrends/

# %%
@df confirmedCasesTop plot(:Value_rolling7, :Value_new_rolling7, group=:Country_Region,
                      yscale=:log10, xscale=:log10, lw=lw, legend=:right,
                      xformatter=fc, yformatter=fc, xminorticks=true, yminorticks=true,
                      xlimit=(minimum(:Value_rolling7), maximum(:Value_rolling7)*10),
                      xlab="Total confirmed cases (log)", ylab="New cases per day (log)",
                      title="Trajectory of Covid-19 cases (7 day avg) (log-log)")

# %% [markdown]
# # Covid 19 deaths

# %%
deaths = getCovid19Data(Deaths, CountryLevel, 3);

# %% [markdown]
# ## US Deaths

# %%
deathsUS = @where(deaths, :Country_Region.=="US" );

# %%
plotActualAnd7DayAvg(deathsUS, :Value_new, :Value_new_rolling7, "New deaths per day")

# %%
plotActualAnd7DayAvg(deathsUS, :Value_new, :Value_new_rolling7, "New deaths per day (log)", true, :right)

# %% [markdown]
# How may deaths are we up to?

# %%
plotActualAnd7DayAvg(deathsUS, :Value, :Value_rolling7, "Total deaths", false, :right)

# %%
plotActualAnd7DayAvg(deathsUS, :Value, :Value_rolling7, "Total deaths (log)", true, :right)

# %% [markdown]
# ## Top Countries for Deaths

# %%
categorical!(deaths, :Country_Region);

# %%
topCountriesDeaths = topCountries(deaths, 10);
push!(topCountriesDeaths, "Sweden")

deathsTop = @where(deaths, in.(:Country_Region, [topCountriesDeaths]), :Value_new .> 0, :Value_new_rolling7 .> 0);

# %%
levels!(deathsTop.Country_Region, topCountriesDeaths)
droplevels!(deathsTop.Country_Region);
ordered!(deathsTop.Country_Region, true);

# %%
levels(deathsTop.Country_Region)

# %%
lw = fill(2, (1,length(topCountriesDeaths)));
lw[1] = 5;

# %% [markdown]
# Since we're doing a long plot, we need positive values...

# %%
@df deathsTop plot(:daysSince, :Value_new_rolling7, group=:Country_Region,
                           yformatter=fc, yminorticks=true, legend=:right, lw=lw, yscale=:log10,
                           xlimit=(0, maximum(:daysSince)*1.3), 
                           xaxis="Days since 30 cases reported", yaxis="New deaths per day (log)",
                           title="New Covid-19 deaths per day (7 day rolling average) (semi-log)")

# %%
@df deathsTop plot(:Value_rolling7, :Value_new_rolling7, group=:Country_Region,
                      yscale=:log10, xscale=:log10, lw=lw, legend=:right,
                      xformatter=fc, yformatter=fc, xminorticks=true, yminorticks=true,
                      xlimit=(minimum(:Value_rolling7), maximum(:Value_rolling7)*20),
                      xlab="Total deaths (log)", ylab="New deaths day (log)",
                      title="Trajectory of Covid-19 deaths (7 day avg) (log-log)")

# %% [markdown]
# # Plots per capita (per million people)
# Comparing the US to other countries in the plots above may be unfair as population may have an influence on number of cases and such (larger countries have more people who can get the virus). Make plots by dividing by the population of the country... per capita plots.

# %% [markdown]
# Get the country population data

# %%
using CSV

# %%
popDataPath = joinpath(@__DIR__, "..", "data", "country_populations.csv")
popData = CSV.read(popDataPath, header=5, skipto=6, select=["Country Name", "2018"]) # header is line 5, data starts on line 6
rename!(x->Symbol(replace(string(x), " " => "")), popData)
rename!(popData, Symbol("2018") => :pop)
popData = @transform(popData, country=replace(:CountryName, "United States" => "US", "Iran, Islamic Rep." => "Iran"));

# %% [markdown]
# ## Cases per capita

# %% [markdown]
# Join this with the top confirmed cases dataframe

# %%
fcpc(x) = format(x, commas=true)

# %%
confirmedCasesTopPerCap = innerjoin(confirmedCasesTop, popData, on=:Country_Region=>:country)
confirmedCasesTopPerCap = @transform(confirmedCasesTopPerCap,
                            Value_rolling7_perCap = :Value_rolling7 ./ :pop .* 1_000_000,
                            Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop .* 1_000_000);

# %%
@df confirmedCasesTopPerCap plot(:daysSince, :Value_new_rolling7_perCap, group=:Country_Region,
                                 xaxis="Days since 30 cases first recorded", yaxis="Number of new cases per day per million",
                                 xlimit=(0, maximum(:daysSince)*1.25), legend=:right, lw=lw)

# %%
@df confirmedCasesTopPerCap plot(:daysSince, :Value_new_rolling7_perCap, group=:Country_Region,
                                 xaxis="Days since 30 cases first recorded", yaxis="Number of new cases per day per million (log)", yscale=:log10,
                                 xlimit=(0, maximum(:daysSince)*1.25), legend=:right, lw=lw, yformatter=fcpc, yminorticks=true)

# %%
@df confirmedCasesTopPerCap plot(:Value_rolling7_perCap, :Value_new_rolling7_perCap, group=:Country_Region,
                                 xscale=:log10, yscale=:log10,
                                 xformatter=fcpc, yformatter=fcpc, legend=:right, lw=lw,
                                 xlimit=(minimum(:Value_rolling7_perCap), maximum(:Value_rolling7_perCap)*20),
                                 xaxis="Total confirmed cases per million per day (log)", 
                                 yaxis="New cases per million (log)")

# %% [markdown]
# ## Deaths per capita

# %%
deathsTopPerCap = innerjoin(deathsTop, popData, on=:Country_Region => :country)
deathsTopPerCap = @transform(deathsTopPerCap,
                             Value_rolling7_perCap = :Value_rolling7 ./ :pop .* 1_000_000,
                             Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop .* 1_000_000);

# %%
@df deathsTopPerCap plot(:daysSince, :Value_new_rolling7_perCap, group=:Country_Region,
                                 xaxis="Days since 3 deaths first recorded", yaxis="Number of new deaths per day per million (log)", yscale=:log10,
                                 xlimit=(0, maximum(:daysSince)*1.25), legend=:right, lw=lw, yformatter=fcpc, yminorticks=true)

# %%
@df deathsTopPerCap plot(:Value_rolling7_perCap, :Value_new_rolling7_perCap, group=:Country_Region,
                                 xscale=:log10, yscale=:log10,
                                 xformatter=fcpc, yformatter=fcpc, legend=:right, lw=lw,
                                 xlimit=(minimum(:Value_rolling7_perCap), maximum(:Value_rolling7_perCap)*50),
                                 xaxis="Total deaths per million per day (log)", 
                                 yaxis="New deaths per million (log)")
