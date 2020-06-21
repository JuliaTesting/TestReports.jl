module TestReports

# package code goes here
using Test
using EzXML

import Test: AbstractTestSet, record, finish, get_testset_depth, get_testset
import Test: Result, Fail, Broken, Pass, Error, scrub_backtrace

export ReportingTestSet, any_problems, report

include("./testsets.jl")
include("to_xml.jl")
include("runner.jl")
end # module
