module Covid19

using Distributed: addprocs, nworkers, workers, @everywhere, @distributed
using Glob, CSV, DataFrames, Missings, Dates, JDF
using DataFramesMeta, RollingFunctions, ShiftedArrays
using Lazy: @>, @>>

const jhu_csse_path = joinpath(@__DIR__, "..", "jhu_csse_covid19")

"""
  Update the Johns Hopkins CSSE data

  Will run git pull on the sub module
"""
function updateJhuCSSE()
	cmd = `git -C $(jhu_csse_path) reset --hard HEAD`
	run(cmd)
	cmd = `git -C $(jhu_csse_path) pull`
	run(cmd)
end

export updateJhuCSSE, ingest, getCovid19Data
export CountryLevel, StateLevel, CountyLevel
export ConfirmedCases, Deaths

include("ingest_multicore.jl")
include("ingest.jl")
include("timeSeries.jl")

end # module
