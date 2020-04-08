# # Ingest the JHU CSSE COVID-19 CSV files

# Johns Hopkins University's Center for Systems Science and Engineering (CSSE) is maintaining what looks to be the most comprehensive dataset of information for the COVID-19 outbreak. They have a GitHub repository at https://github.com/CSSEGISandData/COVID-19 .  In the `ccse_covid_19_data/csse_covid_19_daily_reports` directory they have a CSV (comma separated value) file for every day of the crisis. These CSV files contain location information as well as number of confirmed cases, number of deaths, and in some cases number recovered. Many sites are using this information to make plots and do their analyses. The CSV file is rather complicated and after 3/31/20, the format significantly changed. Furthermore, the date format is not consistent. We'll need to do some processing to make one large data frame of this information.
#
# The strategy here will be to read in a CSV file for a particular day and convert it to a "normalized" format. We'll then merge all the dataframes into one for easy analysis. We could use a database, but in the end there's not that much data (<100K rows and <10 columns) so an in-memory dataframe should be fine. In order to speed up data ingest, we'll try to use some Julia multi-processing techniques. We'll also make it a "running" process so that we can just add new data as they appear instead of reconstituting the whole dataframe for each analysis session. The functions in this file will do this ingest and will write out a binary file that can be loaded in later for analysis. 
#
# Prepare the workers. My laptop has six cores with two hyper-threads each. Let's just use one thread per core.

const csvs = glob("*.csv", joinpath(jhu_csse_path, "csse_covid_19_data/csse_covid_19_daily_reports"))

using Pkg

""" 
    Prepare the worker nodes

    Add processors or cores and load the necessary code. 
"""
function prepare_procs(nDesiredWorkers)
    nworkers() == 1 && addprocs(nDesiredWorkers)
    println("Using $(nworkers()) workers")

    @everywhere workers() @eval begin
        # Activate the same environment on workers as on the master
        using Pkg
        Pkg.activate($(Pkg.API.Context().env.project_file))

        # Load this package
        using Covid19
    end
end

"""
    ingest(outDir[, nDesiredWorkers])

    Ingest the daily reports from Johns Hopkins CSSE and make one large dataframe. Save it with JDF to `outDir`. The daily report files are read in parallel. You can control the number of worker nodes with `nDesiredWorkers`. The default is `Sys.CPU_THREADS/2`. 
"""
function ingest(outDir, nDesiredWorkers=div(Sys.CPU_THREADS,2) )

    prepare_procs(nDesiredWorkers)

    df = @sync @distributed vcat for csvFile in csvs
        println("Processing $(csvFile)")
        readACSV(csvFile)
    end

    savejdf(outDir, df)

    println("Wrote Covid19 data frame to $(outDir)")
    
    return df
end

