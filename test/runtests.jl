using Dates
using EzXML
using ReferenceTests
using Test
using Test: AbstractTestSet, DefaultTestSet, Result, Pass, Fail, Broken, Error
using Test: get_testset, get_testset_depth 
using TestReports

# Include utils
include("utils.jl")

# Include other test scripts
@testset "TestReports" begin
    @testset "testsets" begin include("testsets.jl") end
    @testset "properties" begin include("properties.jl") end
    @testset "report generation" begin include("reportgeneration.jl") end
    @testset "runner internals" begin include("runnerinternals.jl") end
    @testset "to_xml" begin include("to_xml.jl") end
end
