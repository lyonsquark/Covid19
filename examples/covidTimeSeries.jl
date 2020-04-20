# # Plot some Covid19 Time Series data
#
#

# Load in the packages
using Covid19, StatsPlots, DataFramesMeta
using Lazy: @>

plotlyjs()  # will spews lots of warnings - they're ok
default(size=(1200,800))

# Make sure we have the latest data
updateJhuCSSE()

# Get the confirmed global cases dataset
confirmedCases = getJHUTimeSeriesDF(GlobalConfirmedCases, 30) # Start when at least 30 cases

# Just look at the US
confirmedCasesUS = @where(confirmedCases, :Country_Region .== "US", :daysSince .>= 3)

# Plot the growth of cases
p = @df confirmedCasesUS plot(:daysSince, :Value_new_rolling7, 
	title="New Covid-19 cases per day in US (7 day rolling average)", 
	xlabel="Number of days since 30 cases first recorded", 
	ylabel="Number of new cases", label=nothing, lw=3)
savefig("01confirmedCasesUSLin.png")

p = @df confirmedCasesUS plot(:daysSince, :Value_new_rolling7, yaxis=:log10, 
	title="New Covid-19 cases per day in US (7 day rolling average) semi-log", 
	xlabel="Number of days since 30 cases first recorded", 
	ylabel="Number of new cases (log)", label=nothing, lw=3)
savefig("02confirmedCasesUS.png")


# Let's look at the top few countries with cases

function topCountries(df, n)
	tc = @> begin
		df
		@orderby(:Date, :Value)  # Largest go to the bottom
		last(n)
		getindex(:, :Country_Region)
	end
	sort!(tc)
	tc
end

# Top 10 countries
topCountriesCases = topCountries(confirmedCases, 10)
confirmedCasesTop = @where(confirmedCases, in.(:Country_Region, [topCountriesCases]), :Value_new .> 0)

# Set line widths (make US stand out more)
function lineWidths(topCountries)
	lw = fill(1, (1, length(topCountries)))  # Need [1 1 1 1 1 1 ...] e.g. 1x7 array
	lw[ findall( x->x == "US", topCountries) ] .= 3
	lw
end

p = @df confirmedCasesTop plot(:daysSince, :Value_new_rolling7, group=:Country_Region,  
		     yaxis=:log10, lw=lineWidths(topCountriesCases),
	         title="New Covid-19 cases per day (7 day rolling average) semi-log",
	         xlabel="Number of days since 30 cases first recorded",
	         ylabel="Number of new cases (log)")
savefig("03confirmedCasesTop.png")

# China tends to stretch out the plot, let's remove it
confirmedCasesNoChina = @where(confirmedCases, :Country_Region .!= "China")
topCountriesCasesNoChina = topCountries(confirmedCasesNoChina, 10)
confirmedCasesTopNoChina = @where(confirmedCasesNoChina, in.(:Country_Region, [topCountriesCasesNoChina]), :Value_new .> 0)

p = @df confirmedCasesTopNoChina plot(:daysSince, :Value_new_rolling7, group=:Country_Region,  
		     yaxis=:log10, lw=lineWidths(topCountriesCasesNoChina),
	         title="New Covid-19 cases per day (7 day rolling average) without China semi-log",
	         xlabel="Number of days since 30 cases first recorded",
	         ylabel="Number of new cases(log)")
savefig("04confirmedCasesTopNoChina.png")

# Plot new vs. current like https://aatishb.com/covidtrends/

p = @df confirmedCasesTop plot(:Value_rolling7, :Value_new_rolling7, group=:Country_Region, xaxis=:log10, yaxis=:log10, 
	lw=lineWidths(topCountriesCases),
	title="Trajectory of COVID-19 cases (7 day avg) log-log", xlabel="Total confirmed cases (log)", ylabel="New cases (log)")
savefig("05trajectoryConfirmedCasesTop.png")


# ----
# Get deaths

deaths = getJHUTimeSeriesDF(GlobalDeaths, 3)

# Get the top few countries
topCountriesDeaths = topCountries(deaths, 10)
deathsTop = @where(deaths, in.(:Country_Region, [topCountriesDeaths]), :Value_new .> 0)

p = @df deathsTop plot(:daysSince, :Value_new_rolling7, group=:Country_Region, 
	yaxis=:log10, lw=lineWidths(topCountriesDeaths),
	title="New Covid-19 Deaths per day (7 day rolling average) semi-log", 
	xlabel="Number of days since 3 deaths first recorded",
	ylabel="Number of deaths (log)")
savefig("06deathsTop.png")

p = @df deathsTop plot(:Value_rolling7, :Value_new_rolling7, group=:Country_Region, xaxis=:log10, yaxis=:log10,
	lw=lineWidths(topCountriesDeaths),
	title="Trajectory of COVID-19 deaths (7 day avg) log-log",
	xlabel="Total deaths (log)", ylabel="New deaths (log)")
savefig("07trajectoryDeathsTop.png")

# -----
# Get country population data
using CSV, DataFrames
popDataPath = joinpath(@__DIR__, "../data", "country_populations.csv")
# Header is line 5, data starts at line 6
popData = CSV.File(popDataPath, header=5, skipto=6, select=["Country Name", "2018"]) |> DataFrame!
rename!(x->Symbol(replace(string(x), " " => "")), popData)
rename!(popData, Symbol("2018") => :pop)
popData = @transform(popData, country=replace(:CountryName, "United States" => "US", "Iran, Islamic Rep." => "Iran"))

# Join this with the confirmed cases top
@where(popData, in.(:country, [topCountriesCases]))
confirmedCasesTopPerCap = join(confirmedCasesTop, popData, on=:Country_Region=>:country)
confirmedCasesTopPerCap = @transform(confirmedCasesTopPerCap, 
	                         Value_rolling7_perCap = :Value_rolling7 ./ :pop,
	                         Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop)

p = @df confirmedCasesTopPerCap plot(:Value_rolling7_perCap, :Value_new_rolling7_perCap, group=:Country_Region, xaxis=:log10, yaxis=:log10, 
	lw=lineWidths(topCountriesCases), 
	title="Trajectory of COVID-19 cases (7 day avg) per capita log-log", xlabel="Total confirmed cases per capita (log)", ylabel="New cases per capita (log)")
savefig("08trajectoryConfirmedPerCap.png")

# Join with deaths
@where(popData, in.(:country, [topCountriesDeaths]))
deathsTopPerCap = join(deathsTop, popData, on=:Country_Region=>:country)
deathsTopPerCap = @transform(deathsTopPerCap, 
	                         Value_rolling7_perCap = :Value_rolling7 ./ :pop,
	                         Value_new_rolling7_perCap = :Value_new_rolling7 ./ :pop)

p = @df deathsTopPerCap plot(:Value_rolling7_perCap, :Value_new_rolling7_perCap, group=:Country_Region, xaxis=:log10, yaxis=:log10, 
	lw=lineWidths(topCountriesCases), 
	title="Trajectory of COVID-19 deaths (7 day avg) per capita log-log", xlabel="Total deaths per capita (log)", ylabel="New deaths per capita (log)")
savefig("09trajectoryDeathsPerCap.png")