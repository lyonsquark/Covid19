# Deal with the JHU CSSE Timeseries data frames

const pathToCSVs = joinpath(jhu_csse_path, "csse_covid_19_data", "csse_covid_19_time_series")

# Let's rename the columns with slashes
function fixSlashesInColumeNames!(df::DataFrame)
    rename!(n -> Symbol(replace(string(n), "/"=>"_")), df)
end

# Pipeline for transforming a dataframe into something we can use for plotting.
#  
function pipeline(df::DataFrame, threshold, level)
	fixedColumns = [:County, :FIPS, :Population, :Admin2, :Province_State, :Country_Region]
    presentFixedColumns = intersect(fixedColumns, names(df))  # Only keep names present in the DF
    
    presentLevels = intersect(level, names(df))  # Remove levels that aren't there (like Population)

    newDF = @> begin   # Pipe starting with dataframe
	    df

	    stack(Not(presentFixedColumns), variable_name=:DateS, 
                  value_name=:Value)  # make date columns into entries (wide to narrow)

	    @transform(Date=Date.(String.(:DateS), "m_d_y") .+ Dates.Year(2000))  # Make real date types

	    by(vcat(presentLevels, :Date), :Value => sum)   # Aggregate out to the level we want (e.g. :Country_Region)

	    @where(:Value_sum .>= threshold)   # Start where the value is at or over threshold

	    @orderby(:Date)    # Sort by date - earliest date for that threshold should be first for that country

	    ## Determine the days since the first "event"
	    by(presentLevels,
	       [:Date, :Value_sum] => x -> (
	            daysSince = Dates.value.(x.Date .- x.Date[1]),  # We want an Int, not a date period type
	            Date=x.Date,
	            Value=x.Value_sum,
	            Value_new=x.Value_sum .- lag(x.Value_sum, default=0)  # Get the number of new deaths per day
	        )
	    )

	    ## Add the rolling 7 day means
	    by(presentLevels,
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

function fixUS(df::DataFrame)
    # Remove the UID, iso2, iso3, code3, Lat, Long_, and Combined_key columns
    select!(df, setdiff(names(df), [:UID, :iso2, :iso3, :code3, :Lat, :Long_, :Combined_Key]))
end

function fixGlobal(df::DataFrame)
    # Remove Lat and Long
    select!(df, setdiff(names(df), [:Lat, :Long]))
end

# Choose the data level: Country, State, Metro
abstract type DataLevel end
abstract type DataLevelGlobal <: DataLevel end
abstract type DataLevelUS <: DataLevel end

struct CountryLevel <: DataLevelGlobal end
struct StateLevel <: DataLevelUS end
struct CountyLevel <: DataLevelUS end

whatLevel(::Type{CountryLevel}) = [:Country_Region]
whatLevel(::Type{StateLevel})   = [:Province_State]
whatLevel(::Type{CountyLevel})  = [:County, :FIPS, :Population]

abstract type DataKind end
struct ConfirmedCases <: DataKind end
struct Deaths <: DataKind end

# Load dataset according to type
getDF(::Type{ConfirmedCases}, ::Type{<:DataLevelGlobal}) = CSV.read(joinpath(pathToCSVs, "time_series_covid19_confirmed_global.csv")) |> fixGlobal
getDF(::Type{Deaths},         ::Type{<:DataLevelGlobal}) = CSV.read(joinpath(pathToCSVs, "time_series_covid19_deaths_global.csv"))    |> fixGlobal
getDF(::Type{ConfirmedCases}, ::Type{<:DataLevelUS})     = CSV.read(joinpath(pathToCSVs, "time_series_covid19_confirmed_us.csv"))     |> fixUS
getDF(::Type{Deaths},         ::Type{<:DataLevelUS})     = CSV.read(joinpath(pathToCSVs, "time_series_covid19_deaths_us.csv"))        |> fixUS

function prepareDF(df, whichLevel::Type{CountyLevel})
    df.Admin2 = replace(df.Admin2, missing=>"Unknown")  # Some have Admin2 missing
    @transform(df, County = :Admin2 .* ", " .* :Province_State)
end 
    
prepareDF(df, whichLevel::Type{<:DataLevel}) = df

"""
    Get the Covid19 Data as a dataframe

    Arguments:
      whichKind:  Either ConfirmedCases or Deaths
      whichLevel: CountryLevel, StateLevel, CountyLevel
      threshold:  How many cases or deaths to begin counting at

    Returns:
      DataFrame
"""
function getCovid19Data(whichKind::Type{<:DataKind}, whichLevel::Type{<:DataLevel}, threshold::Int)
    # Get the appropriate data frame
    df = getDF(whichKind, whichLevel)
    fixSlashesInColumeNames!(df)
    df = prepareDF(df, whichLevel)
    pipeline(df, threshold, whatLevel(whichLevel))
end
