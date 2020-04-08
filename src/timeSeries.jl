# Deal with the JHU CSSE Timeseries data frames

const pathToCSVs = joinpath(jhu_csse_path, "csse_covid_19_data/csse_covid_19_time_series")

# Let's rename the columns with slashes
function fixSlashesInColumeNames!(df::DataFrame)
    rename!(n -> Symbol(replace(string(n), "/"=>"_")), df)
end

# Pipeline for transforming a dataframe into something we can use for plotting.
#  
function pipeline(df::DataFrame, threshold)
	fixedColumns = [:Province_State, :Country_Region, :Lat, :Long]

	newDF = @> begin   # Pipe starting with dataframe
	    df

	    fixSlashesInColumeNames!

	    stack(Not(fixedColumns), variable_name=:DateS, value_name=:Value)  # make date columns into entries (wide to narrow)

	    @transform(Date=Date.(String.(:DateS), "m_d_y") .+ Dates.Year(2000))  # Make real date types

	    select(:Date, :Value, :Province_State, :Country_Region)   # Select out the columns we care about

	    by([:Country_Region, :Date], :Value => sum)   # Aggregate out the province/state to get country totals for each date

	    @where(:Value_sum .>= threshold)   # Start where the value is at or over threshold

	    @orderby(:Date)    # Sort by date - earliest date for that threshold should be first for that country

	    ## Determine the days since the first "event"
	    by(:Country_Region,
	       [:Date, :Value_sum] => x -> (
	            daysSince = Dates.value.(x.Date .- x.Date[1]),  # We want an Int, not a date period type
	            Date=x.Date,
	            Value=x.Value_sum,
	            Value_new=x.Value_sum .- lag(x.Value_sum, default=0)  # Get the number of new deaths per day
	        )
	    )

	    ## Add the rolling 7 day means
	    by(:Country_Region,
	         [:Date, :daysSince, :Value, :Value_new] => x -> (
	            Date = x.Date,
	            daysSince = x.daysSince,
	            Value = x.Value,
	            Value_new = x.Value_new,
	            Value_rolling7 = runmean(x.Value, min(length(x.Value), 7)),
	            Value_new_rolling7 = runmean(x.Value_new, min(length(x.Value_new), 7))
	         )
	    )

	    @where(:daysSince .> 0)  # Remove the zero (first) day since the running average doesn't work for that day
	end
	newDF
end

# Make types to select the dataset 
abstract type JHUDataSet end
struct GlobalConfirmedCases <: JHUDataSet end
struct GlobalDeaths <: JHUDataSet end

# Load dataset according to type 
getDF(::Type{GlobalConfirmedCases}) = CSV.File(joinpath(pathToCSVs, "time_series_covid19_confirmed_global.csv")) |> DataFrame!
getDF(::Type{GlobalDeaths}) = CSV.File(joinpath(pathToCSVs, "time_series_covid19_deaths_global.csv")) |> DataFrame!

"""
    Get a Johns Hopkins CSSE time series dataframe

    Get a JHU CSSE time series dataframe (like global confirmed cases) narrow view (so the date is an entry instead of a column). Also, calculate number of days the value (confirmed cases or deaths) is over a threshold. Calculate the number of new cases or deaths each day. Caculate running averages.

    The first argument is the type of dataset
        GlobalConfirmedCases, GlobalDeaths

     The second argument is the threshold to start counting (e.g. three for deaths, )
"""
function getJHUTimeSeriesDF(whichDF::Type{<:JHUDataSet}, threshold)
	df = getDF(whichDF)	
	pipeline(df, threshold)
end
