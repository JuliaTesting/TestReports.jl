script_runner = joinpath(pkgdir(TestReports), "bin", "reporttests.jl")
test_script = "reporttests_testsets.jl"

@testset "no specified test script" begin
    @test !success(`$script_runner`)
end

@testset "default output file" begin
    output_file = "testlog.xml"
    @test success(`$script_runner $test_script`)
    try
        @test isfile(output_file)
        @test_reference "references/reporttests_pass.txt" read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end

@testset "specify output file" begin
    output_file = "junit-report.xml"
    @test success(`$script_runner $test_script $output_file`)
    try
        @test isfile(output_file)
        @test_reference "references/reporttests_pass.txt" read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end

@testset "test args" begin
    output_file = "testlog.xml"
    @test !success(`$script_runner $test_script -- foo bar baz`)
    try
        @test isfile(output_file)
        @test_reference "references/reporttests_fail.txt" read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end
