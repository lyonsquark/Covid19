module Covid19

using Distributed: addprocs, nworkers, workers, @everywhere, @distributed
using Glob, CSV, DataFrames, Missings, Dates, JDF
using DataFramesMeta, RollingFunctions, ShiftedArrays
using Lazy: @>, @>>

const jhu_csse_path = joinpath(@__DIR__, "../jhu_csse_covid19")
const csvs = glob("*.csv", joinpath(jhu_csse_path, "csse_covid_19_data/csse_covid_19_daily_reports"))

"""
  Update the Johns Hopkins CSSE data

  Will run git pull on the sub module
"""
function updateJhuCSSE()
	gitfile = joinpath(jhu_csse_path, ".git")
	cmd = `git --git-dir=$(gitfile) pull`
	run(cmd)
end

export updateJhuCSSE, ingest, getJHUTimeSeriesDF
export GlobalConfirmedCases, GlobalDeaths

include("ingest_multicore.jl")
include("ingest.jl")
include("timeSeries.jl")

end # module
