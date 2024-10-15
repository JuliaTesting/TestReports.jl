module TestReports

using Dates
using EzXML
using Pkg
using Printf
using Test
using TestEnv

using Test: AbstractTestSet, DefaultTestSet, Result, Pass, Fail, Error, Broken,
    get_testset, get_testset_depth, scrub_backtrace

import Test: finish, record

export ReportingTestSet, any_problems, report, record_test_property, record_testset_property

const TESTREPORTS_VERSION = let # Copied from Documenter.jl
    project = joinpath(dirname(dirname(pathof(TestReports))), "Project.toml")
    toml = Pkg.TOML.parsefile(project)
    VersionNumber(toml["version"])
end
const TESTREPORTS_UUID = let
    project = joinpath(dirname(dirname(pathof(TestReports))), "Project.toml")
    toml = Pkg.TOML.parsefile(project)
    Base.UUID(toml["uuid"])
end

include("v1_compat.jl")
include("./testsets.jl")
include("to_xml.jl")
include("compat_check.jl")
include("runner.jl")
include("properties.jl")

end # module
