using TestReports
using Test
using ReferenceTests

# Strip the filenames from the string, so that the reference strings work on different computers
strip_filepaths(str) = replace(str, r" at .*\d+$"m => "")

# Replace direction of windows slashes so reference strings work on windows
replace_windows_filepaths(str) = replace(str, ".\\" => "./")

# Replace Int32s so reference strings work on x86 platforms
replace_Int32s(str) = replace(str, "Int32" => "Int64")

@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" read(`$(Base.julia_cmd()) -e "using Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`, String) |> strip_filepaths |> replace_windows_filepaths |> replace_Int32s
end

@testset "Complex Example" begin
    if VERSION >= v"1.4.0"
        @test_reference "references/complexexample.txt" read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> strip_filepaths |> replace_windows_filepaths |> replace_Int32s
    else
        @test_reference "references/complexexample_julia_1_3.txt" read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> strip_filepaths |> replace_windows_filepaths |> replace_Int32s
    end
end


@testset "any_problems" begin

    fail_code = """
    using Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test false == true
    end;
    exit(any_problems(ts))
    """

    @test_throws Exception run(`$(Base.julia_cmd()) -e $(fail_code)`)


    pass_code = """
    using Test
    using TestReports
    ts = @testset ReportingTestSet "eg" begin
        @test true == true
    end;
    exit(any_problems(ts))
    """

    @test run(`$(Base.julia_cmd()) -e $(pass_code)`) isa Any #this line would error if fail



end
