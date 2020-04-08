# # Plot some Covid19 Time Series data
#
#

# Load in the packages
using Covid19, StatsPlots, DataFramesMeta, 
using Lazy: @>

plotlyjs()  # will spews lots of warnings - they're ok

# Get the confirmed global casses dataset
confirmedCases = getJHUTimeSeriesDF(GlobalConfirmedCases, 30) # Start when at least 30 cases

# Just look at the US
confirmedCasesUS = @where(confirmedCases, :Country_Region .== "US", :daysSince .>= 3)

# Plot the growth of cases
p = @df confirmedCasesUS plot(:daysSince, :Value_new_rolling7, yaxis=:log10, 
	title="New Covid-19 cases per day in US (7 day rolling average)", 
	xlabel="Number of days since 30 cases first recorded", 
	ylabel="Number of new cases (log)", label=nothing, lw=3)

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
	         title="New Covid-19 cases per day (7 day rolling average)",
	         xlabel="Number of days since 30 cases first recorded",
	         ylabel="Number of new cases(log)")

# China tends to stretch out the plot, let's remove it
confirmedCasesNoChina = @where(confirmedCases, :Country_Region .!= "China")
topCountriesCasesNoChina = topCountries(confirmedCasesNoChina, 10)
confirmedCasesTopNoChina = @where(confirmedCasesNoChina, in.(:Country_Region, [topCountriesCasesNoChina]), :Value_new .> 0)

p = @df confirmedCasesTopNoChina plot(:daysSince, :Value_new_rolling7, group=:Country_Region,  
		     yaxis=:log10, lw=lineWidths(topCountriesCasesNoChina),
	         title="New Covid-19 cases per day (7 day rolling average)",
	         xlabel="Number of days since 30 cases first recorded",
	         ylabel="Number of new cases(log)")

# Plot new vs. current like https://aatishb.com/covidtrends/

p = @df confirmedCasesTop plot(:Value_rolling7, :Value_new_rolling7, group=:Country_Region, xaxis=:log10, yaxis=:log10, 
	lw=lineWidths(topCountriesCases),
	title="Trajectory of COVID-19 cases (7 day avg)", xlabel="Total confirmed cases (log)", ylabel="New cases (log)")
