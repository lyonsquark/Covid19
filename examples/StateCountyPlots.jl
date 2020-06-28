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
# <span style="font-size:3em;">US State Covid19 plots</span>
#
# Note that you can manipulate the plots. You can...
#
# * Single click on a label in the legend (e.g. "New York") and remove that line from the plot (single click again to bring it back)
# * Double click on a label in the legend (e.g. "New York") and only show that line in the plot (double click again to bring back the others)
# * Hover over a line to see its value. You can change what you see. Clicking on the top row third icon from the right will show a single value for the line closest to your pointer [this is useful]. Clicking on the top row second icon from the right will show all values (the default). 

# %%
using Covid19     # My package under development
using DataFrames, DataFramesMeta
using Pipe

# %% [markdown]
# # Get the data

# %%
updateJhuCSSE()

# %%
confirmedByState = getCovid19Data(ConfirmedCases, StateLevel, 10);
categorical!(confirmedByState, :Province_State)
nrow(confirmedByState)

# %%
deathsByState = getCovid19Data(Deaths, StateLevel, 3);
categorical!(deathsByState, :Province_State)
nrow(deathsByState)

# %%
maximum(confirmedByState.Date)

# %%
maximum(deathsByState.Date)

# %% [markdown]
# # Look at the states with the most cases

# %%
function topLevels(df::DataFrame, n::Int, Level)
    tc = @pipe df |> 
               sort(_, [:Date, :Value], rev=(true, true)) |>  # Sort by date (reverse) and # cases (reverse)
               first(_, n) |>                                 # Get the n largest
               getindex(_, :, Level)                          # Get the values of the country/region/state name
    
    String.(tc)   # We want the names as strings, not categories
end

# %%
topStatesCases = topLevels(confirmedByState, 10, :Province_State)

# %%
topStatesDeaths = topLevels(deathsByState, 10, :Province_State)

# %%
"North Carolina" ∉ topStatesCases && push!(topStatesCases, "North Carolina");  # Add NC and AZ
"Arizona" ∉ topStatesCases && push!(topStatesCases, "Arizona");

# %%
# Restrict the datasets
confirmedByStateTop = @where(confirmedByState, in.(:Province_State, [topStatesCases]),  :Value_new .> 0);
deathsByStateTop    = @where(deathsByState,    in.(:Province_State, [topStatesDeaths]), :Value_new .> 0);

# %%
# Deal with the levels
function dealWithLevels!(df, theLevels)
    levels!(df.Province_State, theLevels)
    droplevels!(df.Province_State)
    ordered!(df.Province_State, true)
end

dealWithLevels!(confirmedByStateTop, topStatesCases)
dealWithLevels!(deathsByStateTop, topStatesDeaths);

# %%
# Set up plotting
using Plots, StatsPlots, Format
plotlyjs(size=(700,400))

# Format numbers with commas
fc(x) = format(x, commas=true, precision=0)
fcl(x) = format(x, commas=true)

# %%
lwConfirmed = fill(2, (1, length(topStatesCases)))
lwDeaths = fill(2, (1, length(topStatesDeaths)))
lwConfirmed[ topStatesCases .== "Illinois" ] .= 4 ;
lwDeaths[ topStatesDeaths .== "Illinois" ] .= 4 ;

# %%
p = @df confirmedByStateTop plot(:daysSince, :Value_new_rolling7, group=:Province_State,
                             legend=:topright, yformatter=fc, lw=lwConfirmed,
                             xlimit=(0, maximum(:daysSince)*1.3),
                             title="New cases per day (7 day average)",
                             ylab="New cases (7 day avg)",
                             xlab="Days since 10 cases"
                             )
# %% [markdown]
# Let's remove NY, since that dominates.

# %%
@df filter(:Province_State => !=("New York"), confirmedByStateTop) plot(:daysSince, :Value_new_rolling7, group=:Province_State,
                                 yformatter=fc, lw=2, xlimit=(0, maximum(:daysSince)*1.3), legend=:right,
                                 title="New cases per day (7 day average) (without NY)",
                                 ylab="New cases (7 day avg)",
                                 xlab="Days since 10 cases"
                                 )

# %%
@df confirmedByStateTop plot(:daysSince, :Value_new_rolling7, group=:Province_State,
                             legend=:bottomright, yformatter=fc, lw=lwConfirmed, yscale=:log10,
                             xlimit=(0, maximum(:daysSince)*1.3),
                             title="New cases per day (7 day average) (semi-log)",
                             ylab="New cases (7 day avg) log)",
                             xlab="Days since 10 cases"
                            )

# %%
# A linear plot doesn't make much sense since NY dominates
@df deathsByStateTop plot(:daysSince, :Value_new_rolling7, group=:Province_State,
                          lw=lwDeaths, yscale=:log10, yformatter=fc, xlimit=(0, maximum(:daysSince)*1.3),
                          legend=:right,
                          title="New deaths per day (7 day avg) (semi-log)",
                          xlab="Days since 3 deaths", ylab="New deaths per day (7 day avg) (log)")


# %%
@df confirmedByStateTop plot(:Value_rolling7, :Value_new_rolling7, group=:Province_State, 
                          xscale=:log10, yscale=:log10, legend=:right, lw=lwConfirmed, 
                          xlim=(minimum(:Value_rolling7), maximum(:Value_rolling7)*15),
                          title="Trajectory of Covid-19 cases (7 day avg) (log-log)",
                          xlab="Total confirmed cases (log)", ylab="New cases per day (log)")



# %% [markdown]
# # Per capita plots (per 100,000 people)

# %%
using CSV, DataFrames

# %%
popDataPath = joinpath(@__DIR__, "../data", "nst-est2019-alldata.csv")
popData = CSV.read(popDataPath, select=["NAME", "POPESTIMATE2019"]);
rename!(popData, :POPESTIMATE2019 => :pop);

# %%
confirmedByStatePerCap = innerjoin(confirmedByState, popData, on=:Province_State=>:NAME);
deathsByStatePerCap = innerjoin(deathsByState, popData, on=:Province_State=>:NAME);

# %%
nrow(deathsByStatePerCap)

# %%
confirmedByStatePerCap = @transform(confirmedByStatePerCap,
                            Value_perCap = :Value ./ :pop .* 100_000,
                            Value_rolling7_perCap = :Value_rolling7 ./ :pop .* 100_000,
                            Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop .* 100_000);
deathsByStatePerCap = @transform(deathsByStatePerCap,
                            Value_perCap = :Value ./ :pop .* 100_000,
                            Value_rolling7_perCap = :Value_rolling7 ./ :pop .* 100_000,
                            Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop .* 100_000);

# %% [markdown]
# Find the new top states

# %%
topStatesCasesPerCap = topLevels(confirmedByStatePerCap, 10, :Province_State);
"North Carolina" ∉ topStatesCasesPerCap && push!(topStatesCasesPerCap, "North Carolina")
"Arizona" ∉ topStatesCasesPerCap && push!(topStatesCasesPerCap, "Arizona")

# %%
topStatesDeathsPerCap = topLevels(deathsByStatePerCap, 10, :Province_State);
"North Carolina" ∉ topStatesDeathsPerCap && push!(topStatesDeathsPerCap, "North Carolina")
"Arizona" ∉ topStatesDeathsPerCap && push!(topStatesDeathsPerCap, "Arizona")

# %%
# Restrict the datasets
confirmedByStateTopPerCap = @where(confirmedByStatePerCap, in.(:Province_State, [topStatesCasesPerCap]),  :Value_new .> 0);
deathsByStateTopPerCap    = @where(deathsByStatePerCap,    in.(:Province_State, [topStatesDeathsPerCap]), :Value_new .> 0);

# %%
# Deal with levels
dealWithLevels!(confirmedByStateTopPerCap, topStatesCasesPerCap)
dealWithLevels!(deathsByStateTopPerCap, topStatesDeathsPerCap);

# %%
@df confirmedByStateTopPerCap plot(:daysSince, :Value_new_rolling7_perCap, group=:Province_State,
                             legend=:bottomright, yformatter=fcl, lw=lwConfirmed, yscale=:log10,
                             xlimit=(0, maximum(:daysSince)*1.3), ylimit=(0.0001, 100),
                             title="New cases per day per 100K (7 day average) (semi-log)",
                             ylab="New cases per 100K (7 day avg) (log)",
                             xlab="Days since 10 cases"
                            )

# %%
@df deathsByStateTopPerCap plot(:daysSince, :Value_new_rolling7_perCap, group=:Province_State,
                             legend=:bottomright, yformatter=fcl, lw=lwConfirmed, yscale=:log10,
                             xlimit=(0, maximum(:daysSince)*1.3), ylimit=(0.001, 10),
                             title="New deaths per day per 100K (7 day average) (semi-log)",
                             ylab="New deaths per 100K (7 day avg) (log)",
                             xlab="Days since 3 deaths"
                            )

# %% [markdown]
# # Largest growth
# Let's look at the states that are experiencing the largest growth in the number of cases for the past two weeks.

# %%
function fastestGrowth(valueColumn)
    @pipe confirmedByStatePerCap |> 
          groupby(_, :Province_State) |>     # Separate by state
          combine(_, valueColumn => ( x -> x[end] - x[end-14]) => :twoWkGrowth) |>  # Compare latest value to two weeks ago
          sort(_, :twoWkGrowth, rev=true)
end

# %%
fg = fastestGrowth(:Value);

# %%
using PrettyTables

# %%
pretty_table(fg, ["State", "Two week growth in cases"], alignment=[:r, :c], backend=:html; formatters = ft_printf("%'d"))

# %%
fgpc = fastestGrowth(:Value_perCap);

# %%
pretty_table(fgpc, ["State", "Two week growth in cases per 100K people"], alignment=[:r, :c], backend=:html; formatters = ft_printf("%'5.1f"))

# %% [markdown]
# # States by governor's party

# %% [markdown]
# Someone posted on Facebook a plot of state cases by governor party. 
#
# I don't think this looks right. Let's try it ourselves.
#
# Getting the Governors data

# %%
govsDataPath = joinpath(@__DIR__, "../data", "us-governors.csv")
govsData = CSV.read(govsDataPath, select=["state_name", "party", "name"]);

# %%
govsData

# %%
ENV["COLUMNS"] = 200

# %%
cpc_wparty = innerjoin(confirmedByStatePerCap, govsData, on=:Province_State => :state_name) ;

# %%
cpc_d = filter(r -> r.party == "democrat", cpc_wparty);
cpc_r = filter(r -> r.party == "republican", cpc_wparty);

# %%
cpc_d = combine(groupby(cpc_d, :Date), [:Value_new_rolling7_perCap] => sum => :Value_new_rolling7_perCap);
cpc_r = combine(groupby(cpc_r, :Date), [:Value_new_rolling7_perCap] => sum => :Value_new_rolling7_perCap);

# %%
@df cpc_d plot( :Date, :Value_new_rolling7_perCap, label="democrat", legend=:left, lw=3, xlab="Date", ylab="New cases per 100K people")
@df cpc_r plot!(:Date, :Value_new_rolling7_perCap, label="republican", lw=3)

# %%
