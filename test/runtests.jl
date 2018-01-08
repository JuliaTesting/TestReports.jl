using TestReports
using Base.Test
using ReferenceTests


@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" readstring(`$(Base.julia_cmd()) -e "using Base.Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`)
end

@testset "Complex Example" begin
    @test_reference "references/complexexample.txt" readstring(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`)
end


@testset "any_problems" begin
    
    fail_code = """
    using Base.Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test false == true
    end;
    exit(any_problems(ts))
    """
    
    @test_throws ErrorException run(`$(Base.julia_cmd()) -e $(fail_code)`)
    
     
    pass_code = """
    using Base.Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test true == true
    end;
    exit(any_problems(ts))
    """
    
    @test run(`$(Base.julia_cmd()) -e $(pass_code)`) isa Any #this line would error if fail
    
    

end
