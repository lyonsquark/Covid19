# Note that this file, ingest.jl, is only included by ingest_multicore.jl

"""
    Ingest the CSV files and write JDF output
"""

using CSV, DataFrames, Missings, Dates
using Lazy: @>>

# ## Processing a CSV file
#
# We need some functions that will read and process a CSV file. Here's a sketch of what they collectively need to do
# * Determine the format of the CSV. Currently, there are two formats. One with a FIPS field (FIPS is some location info we won't use) and one without.
# * Read in the CSV according to the format
# * Normalize to our "standard format", adding empty columns as necessary
# * Regularize the date to the Julia Date type

# We're going to play some games with multiple dispatch. Instead of having an if statement to determine which fuction to all to read in the CSV file, we'll determine the format, return a type that represents that format (currently A and B) and then we can dispatch on that type to call the right read function. Pretty neat. See https://pixorblog.wordpress.com/2018/02/23/julia-dispatch-enum-vs-type-comparison/ for more information
#
# Note that we need to ensure that the Last Update is read as a string. You may see warnings about the last line having the wrong number of
# fields. That seems to be because the last field doesn't have a value and doesn't have a newline. Those warnings are benign.
abstract type CCSEFormat end
struct CCSEFormat_A <: CCSEFormat end
struct CCSEFormat_B <: CCSEFormat end

function determineCSVFormat(csvFile::String)
    # Read the header line of the CSV
    hasFIPS = @>> readline(csvFile) occursin("FIPS")  # Does it have a "FIPS" column?
    return !hasFIPS ? CCSEFormat_A : CCSEFormat_B
end

function replaceMissing!(df)
    df.Confirmed = replace(df.Confirmed, missing=>0)
    df.Deaths = replace(df.Deaths, missing=>0)
    df.Recovered = replace(df.Recovered, missing=>0)
    df.Province_State = replace(df.Province_State, missing=>"")
    df.Admin2 = replace(df.Admin2, missing=>"")
end

## Read format A CSV
function read_CCSE_CSV(csvFile::String, ::Type{CCSEFormat_A})
    df = CSV.File(csvFile; normalizenames=true, types=Dict(3=>String)) |> DataFrame!
    ## Note that the select option causes a BoundsError on the 2020-03-10 file; not sure why

    ## Drop the unneeded columns
    select!(df, 1:6)

    ## We need to add the Admin2 column as blank
    insertcols!(df, 1, Admin2=fill("", nrow(df)))

    ## Fix missing entries
    replaceMissing!(df)
    return df
end

## Read format B CSV
function read_CCSE_CSV(csvFile::String, ::Type{CCSEFormat_B})
    df = CSV.File(csvFile; normalizenames=true, types=Dict(5=>String)) |>  DataFrame!
    select!(df, [2,3,4,5,8,9,10])  ## Drop unneeded columns
    replaceMissing!(df)
    return df
end

## Now, we need to figure out what to do with the date - we just want the date, not the time. The Last_Update is very unreliable - just don't use it. I'll keep the function here though.
function fixDate!(df)
    theDates = string.(df.Last_Update)
    if occursin("/", theDates[1])
        insertcols!(df, 1, date=Date.(theDates, "m/d/y H:M"))
    elseif occursin("T", theDates[1])
        insertcols!(df, 1, date=Date.(theDates, "y-m-dTH:M:S"))
    else
        insertcols!(df, 1, date=Date.(theDates, "y-m-d H:M:S"))
    end
end

## Add the date of the file name to the DataFrame
function addFileName!(df, csvFile)
    theDate = @> csvFile basename splitext getindex(1) Date("m-d-y")
    insertcols!(df, 2, Date=fill(theDate, nrow(df)))
end

# Here's the function that puts all this together
function readACSV(csvFile)
    df = read_CCSE_CSV(csvFile, determineCSVFormat(csvFile))
    addFileName!(df, csvFile)
    return df
end
