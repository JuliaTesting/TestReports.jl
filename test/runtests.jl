using TestReports
using Test
using ReferenceTests
using UUIDs
using Pkg

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
        @warn "skipping complex reference test on pre-Julia 1.4"
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

const TEST_PKG = (name = "Example", uuid = UUID("7876af07-990d-54b4-ab0e-23690620f79a"))

"""
Helper function to verify the runner successfully ran a test suite based on
the Info messages that were logged.
"""
function test_successful_testrun(testrun::Function, project::AbstractString)
    successful_pass_matcher = Regex("$(project) tests passed. Results saved to .+\\.\$")
    @test_logs (:info, "Testing $(project)") (:info, successful_pass_matcher) testrun()
end

""""
Helper function to execute 'work' within the context of an active
project. The `project` should be `Pkg.develop`able.
"""
function with_active_project(work_within_context::Function, project::AbstractString)
    Pkg.develop(project; shared = false)
    Pkg.activate(project)

    work_within_context()

    Pkg.activate()
    Pkg.rm(project)
end

@testset "Runner tests" begin
    @testset "installed packages by name" begin
        Pkg.add(TEST_PKG.name)
        test_successful_testrun(() -> TestReports.test(TEST_PKG.name), TEST_PKG.name)
        Pkg.rm(TEST_PKG.name)
        @test_throws TestReports.PkgTestError TestReports.test("Example")
    end

    @testset "activated projects" begin
        @testset "by name" begin
            # The test run should not fail when passed the name of the project
            # that is activated and fail when its deactivated
            with_active_project(TEST_PKG.name) do
                test_successful_testrun(() -> TestReports.test(TEST_PKG.name), TEST_PKG.name)
            end
            @test_throws TestReports.PkgTestError TestReports.test(TEST_PKG.name)
        end

        @testset "implicitly without positional arguments" begin
            # The test run should not fail when a project is implied through
            # one being active
            with_active_project(TEST_PKG.name) do
                test_successful_testrun(TestReports.test, TEST_PKG.name)
            end

            # The test run should fail with a descriptive message when a
            # project is implied, but none is active (e.g. if a shared
            # environment is active).
            #
            # This needs to be tested explicitly in the context of a shared
            # environment, as otherwise `Pkg.activate` may revert back to a
            # 'home project' (e.g. as specified by a `JULIA_PROJECT`
            # environment variables as is the case on Travis CI)
            Pkg.activate("@v$(VERSION.major).$(VERSION.minor)"; shared = true)
            @test_throws TestReports.PkgTestError TestReports.test()
            Pkg.activate()
        end
    end
end
