using Test
using TestReports

(@testset ReportingTestSet "Example" begin
    include("example_normaltestsets.jl")
end) |> report |> println
