@testset "runner script" begin
    @test isdefined(TestReports, :RUNNER_SCRIPT)
    @test isfile(TestReports.RUNNER_SCRIPT)

    if Sys.islinux()
        @test uperm(TestReports.RUNNER_SCRIPT) & 0x01 != 0
        @test gperm(TestReports.RUNNER_SCRIPT) & 0x01 != 0
        @test operm(TestReports.RUNNER_SCRIPT) & 0x01 != 0
    end
end

runner_cmd = if Sys.iswindows()
    `julia $(TestReports.RUNNER_SCRIPT) --`
else
    `$(TestReports.RUNNER_SCRIPT)`
end
test_script = "reporttests_testsets.jl"
reference_suffix = VERSION >= v"1.7" ? "" : "_pre_1_7"

@testset "parse_args" begin
    include(TestReports.RUNNER_SCRIPT)
    @test parse_args([]) === nothing  # Shows help
    @test_throws ArgumentError parse_args(["--"])

    parsed = parse_args(split("script.jl"))
    @test parsed.test_filename == "script.jl"
    @test parsed.output_filename === nothing
    @test parsed.test_args == String[]

    output_filename = "junit-report.xml"
    @testset "$output" for output in (
        "--output $output_filename",
        "-o $output_filename",
        "--output=$output_filename",
        "-o=$output_filename")

        parsed = parse_args(split("script.jl $output"))
        @test parsed.test_filename == "script.jl"
        @test parsed.output_filename == output_filename
        @test parsed.test_args == String[]
    end

    parsed = parse_args(split("script.jl foo bar -- -o baz"))
    @test parsed.test_args == String["foo", "bar", "-o", "baz"]

    parsed = parse_args(split("script.jl -- foo bar -- -o baz"))
    @test parsed.test_args == String["foo", "bar", "--", "-o", "baz"]

    parsed = parse_args(split("-- script.jl foo bar -- -o baz"))
    @test parsed.test_args == String["foo", "bar", "-o", "baz"]

    @testset "$help" for help in ("--help", "-h")
        parsed = parse_args([help])
        @test parsed === nothing
    end
end

@testset "no specified test script" begin
    p = run(ignorestatus(`$runner_cmd`))
    @test !success(p)
end

@testset "default output file" begin
    reference_file = "references/reporttests_pass$reference_suffix.xml"
    output_file = "testlog.xml"
    p = run(ignorestatus(`$runner_cmd $test_script`))
    try
        @test success(p)
        @test isfile(output_file)
        @test_reference reference_file read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end

@testset "specify output file" begin
    reference_file = "references/reporttests_pass$reference_suffix.xml"
    output_file = "junit-report.xml"
    p = run(ignorestatus(`$runner_cmd $test_script --output=$output_file`))
    try
        @test success(p)
        @test isfile(output_file)
        @test_reference reference_file read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end

@testset "test args" begin
    reference_file = "references/reporttests_fail$reference_suffix.xml"
    output_file = "testlog.xml"
    p = run(ignorestatus(`$runner_cmd $test_script -- foo -e bar`))
    try
        @test !success(p)
        @test isfile(output_file)
        @test_reference reference_file read(output_file, String) |> clean_output
    finally
        isfile(output_file) && rm(output_file)
    end
end
