using TestReports
using Test

# Include utils
include("utils.jl")

# Include other test scripts
@testset "TestReports" begin
    @testset "testsets" begin include("testsets.jl") end
    @testset "record property" begin include("recordproperty.jl") end
    @testset "report generation" begin include("reportgeneration.jl") end
    @testset "runner internals" begin include("runnerinternals.jl") end
end
