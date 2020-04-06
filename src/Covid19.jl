module Covid19

using Distributed: addprocs, nworkers, workers, @everywhere, @distributed
using Glob, CSV, DataFrames, Missings, Dates, JDF
using Lazy: @>, @>>

csvs = glob("*.csv", joinpath(@__DIR__,"../jhu_csse_covid19/csse_covid_19_data/csse_covid_19_daily_reports"))

export ingest

include("ingest_multicore.jl")
include("ingest.jl")

end # module
