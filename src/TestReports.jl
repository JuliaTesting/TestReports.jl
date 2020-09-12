module TestReports

# package code goes here
using Test
using EzXML

import Test: AbstractTestSet, DefaultTestSet, record, finish, get_testset_depth, get_testset
import Test: Result, Fail, Broken, Pass, Error, scrub_backtrace

export ReportingTestSet, any_problems, report, recordproperty

include("./testsets.jl")
include("to_xml.jl")
include("runner.jl")
include("recordproperty.jl")

end # module
