module TestReports

# package code goes here
using Base.Test
using EzXML

import Base.Test: AbstractTestSet, record, finish, get_testset_depth, get_testset
import Base.Test: Result, Fail, Broken, Pass, Error, scrub_backtrace

export ReportingTestSet

include("./testsets.jl")
include("to_xml.jl")
include("runner.jl")
end # module
