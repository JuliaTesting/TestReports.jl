using TestReports
using Base.Test
using ReferenceTests


@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" readstring(`$(JULIA_HOME)/julia -e "using Base.Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> print"`)
end

@testset "Complex Example" begin
    @test_reference "references/complexexample.txt" readstring(`$(JULIA_HOME)/julia $(@__DIR__)/example.jl`)
end


