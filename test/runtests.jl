using TestReports
using Base.Test
using ReferenceTests


@testset "SingleNest" begin
    @test_reference "singlenest.txt" readstring(`$(JULIA_HOME)/julia -e "using Base.Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> print"`)
end

