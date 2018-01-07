using Base.Test
using TestReports

(@testset ReportingTestSet "Example" begin
    include("example_normaltestsets.jl")
end) |> println
