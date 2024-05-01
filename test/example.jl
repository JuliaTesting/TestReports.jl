using Test
using TestReports

(@testset ReportingTestSet "" begin
    include("example_normaltestsets.jl")
end) |> report |> println
