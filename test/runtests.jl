using TestReports
using Test
import Test: Fail, Broken, Pass, Error 
using ReferenceTests
using UUIDs
using Pkg

# Include utils
include("utils.jl")

# Strip the filenames from the string, so that the reference strings work on different computers
strip_filepaths(str) = replace(str, r" at .*\d+$"m => "")

# Replace direction of windows slashes so reference strings work on windows
replace_windows_filepaths(str) = replace(str, ".\\" => "./")

# Replace Int32s so reference strings work on x86 platforms
replace_Int32s(str) = replace(str, "Int32" => "Int64")

# remove stacktraces so reference strings work for different Julia versions
remove_stacktraces(str) = replace(str, r"(Stacktrace:)[^<]*" => "")

const clean_report = replace_Int32s ∘ replace_windows_filepaths ∘ strip_filepaths ∘ remove_stacktraces

@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" read(`$(Base.julia_cmd()) -e "using Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`, String) |> clean_report
end

@testset "Complex Example" begin
    @test_reference "references/complexexample.txt" read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> clean_report
end


@testset "any_problems" begin
    @test any_problems(Pass(Symbol(), nothing, nothing, nothing)) == false
    @test any_problems(Fail(Symbol(), nothing, nothing, nothing, LineNumberNode(1))) == true
    @test any_problems(Broken(Symbol(1), nothing)) == false
    @test any_problems(Error(Symbol(), nothing, nothing, nothing, LineNumberNode(1))) == true

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

@testset "Runner tests" begin
    @testset "installed packages by name" begin
        # Pkd.add
        Pkg.add(TEST_PKG.name)
        test_successful_testrun(() -> TestReports.test(TEST_PKG.name), TEST_PKG.name)
        Pkg.rm(TEST_PKG.name)
        @test_throws TestReports.PkgTestError TestReports.test(TEST_PKG.name)

        # Pkd.develop
        pkgname = "PassingTests"
        Pkg.develop(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
        test_successful_testrun(() -> TestReports.test(pkgname), pkgname)
        Pkg.rm("PassingTests")
    end

    @testset "activated projects" begin
        @testset "by name" begin
            # The test run should not fail when passed the name of the project
            # that is activated and fail when its deactivated
            test_active_package_expected_pass("PassingTests")
            @test_throws TestReports.PkgTestError TestReports.test(TEST_PKG.name)
        end

        @testset "implicitly without positional arguments" begin
            # The test run should not fail when a project is implied through
            # one being active
            temp_pkg_dir() do tmp
                copy_test_package(tmp, "PassingTests")
                Pkg.activate(joinpath(tmp, "PassingTests"))
                test_successful_testrun(TestReports.test, "PassingTests")
            end

            # The test run should fail with a descriptive message when a
            # project is implied, but none is active (e.g. if a shared
            # environment is active).
            temp_pkg_dir() do tmp
                @test_throws TestReports.PkgTestError TestReports.test()
            end
        end
    end
end

if VERSION < v"1.2.0"
    @testset "gettestfilepath - V1.0.5" begin
        # Stdlibs are not tested by other functions for V1.0.5
        stdlibname = "Dates"
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(stdlibname)
        TestReports.checkinstalled!(ctx.env, pkg)
        delete!(ctx.env.manifest[stdlibname][1], "path")  # Remove path to force stdlib check
        testfilepath = joinpath(abspath(joinpath(dirname(Base.find_package(stdlibname)), "..")), "test", "runtests.jl")
        @test TestReports.gettestfilepath(ctx, pkg) == testfilepath

        # PkgTestError when PkgSpec has missing info when finding path - V1.0.5 only
        pkgname = "PassingTests"
        Pkg.develop(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
        ctx = Pkg.Types.Context()
        pkg = Pkg.PackageSpec(pkgname)
        TestReports.checkinstalled!(ctx.env, pkg)
        delete!(ctx.env.manifest["PassingTests"][1], "path")
        @test_throws TestReports.PkgTestError TestReports.gettestfilepath(ctx, pkg)
        Pkg.rm(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
    end
end

@testset "Test packages" begin
    # Errors
    test_active_package_expected_fail("FailedTest")
    test_active_package_expected_fail("ErroredTest")
    test_active_package_expected_fail("NoTestFile")

    # Various test dependencies
    test_pkgs = [
        "TestsWithDeps",
        "TestsWithTestDeps"
    ]
    for pkg in test_pkgs
        test_active_package_expected_pass(pkg)
    end

    # Test file project file tests, 1.2 and above
    @static if VERSION >= v"1.2.0"
        test_pkgs = [
            "TestsWithProjectFile",
            "TestsWithProjectFileWithTestDeps"
        ]
        for pkg in test_pkgs
            test_active_package_expected_pass(pkg)
        end
    end

    # Test arguments
    temp_pkg_dir() do tmp
        pkg = "TestArguments"
        copy_test_package(tmp, pkg)
        Pkg.activate(joinpath(tmp, pkg))
        test_successful_testrun(() -> TestReports.test(pkg; test_args=`a b`, julia_args=`--quiet --check-bounds=no`), pkg)
        test_successful_testrun(() -> TestReports.test(pkg; test_args=["a", "b"], julia_args=`--quiet --check-bounds=no`), pkg)
    end
end

@testset "ReportingTestSet Display" begin
    # Test adding of results
    ts_default = Test.DefaultTestSet("")
    TestReports.add_to_ts_default!(ts_default, Test.Pass(:null, nothing, nothing, nothing))
    @test length(ts_default.results) == 0
    @test ts_default.n_passed == 1
    TestReports.add_to_ts_default!(ts_default, Test.Fail(:null,:(1==2),nothing,nothing,LineNumberNode(1)))
    @test ts_default.n_passed == 1
    @test typeof(ts_default.results[1]) == Test.Fail
    TestReports.add_to_ts_default!(ts_default, Test.Error(:null,:(1==2),nothing,nothing,LineNumberNode(1)))
    @test ts_default.n_passed == 1
    @test typeof(ts_default.results[2]) == Test.Error

    # Test adding of test set
    ts_reporting = ReportingTestSet("rts")
    Test.record(ts_reporting, Test.Pass(:null, nothing, nothing, nothing))
    TestReports.add_to_ts_default!(ts_default, ts_reporting)
    @test typeof(ts_default.results[3]) == Test.DefaultTestSet

    # Test displaying of results doesn't change reporting test set
    ts_reporting_copy = deepcopy(ts_reporting)
    @test TestReports.display_reporting_testset(ts_reporting) == nothing
    @test ts_reporting_copy.results == ts_reporting.results

    # Test fail/error in results doesn't throw error
    Test.record(ts_reporting, Fail(Symbol(), 1, "1", "1", LineNumberNode(1)))
    @test TestReports.display_reporting_testset(ts_reporting) == nothing
end

@testset "showerror" begin
    @test_throws TestReports.PkgTestError throw(TestReports.PkgTestError("Test"))
    @test sprint(showerror, TestReports.PkgTestError("Error text"), "") == "Error text"
end

@testset "logfile options" begin
    Pkg.add(TEST_PKG.name)

    # Single package tests
    TestReports.test(TEST_PKG.name)
    @test isfile(joinpath(pwd(),"testlog.xml"))
    TestReports.test(TEST_PKG.name; logfilename="changedname.xml")
    @test isfile(joinpath(pwd(),"changedname.xml"))
    new_path = joinpath(pwd(), "NonExistentDir")
    TestReports.test(TEST_PKG.name; logfilename="testlog.xml", logfilepath=new_path)
    @test isfile(joinpath(new_path,"testlog.xml"))

    # Multiple package test
    temp_pkg_dir() do tmp
        copy_test_package(tmp, "PassingTests")
        Pkg.develop(Pkg.PackageSpec(path=joinpath(tmp, "PassingTests")))
        Pkg.add(TEST_PKG.name)
        TestReports.test([TEST_PKG.name, "PassingTests"])
        @test isfile(joinpath(pwd(),"Example_testlog.xml"))
        @test isfile(joinpath(pwd(),"PassingTests_testlog.xml"))
        TestReports.test([TEST_PKG.name, "PassingTests"]; logfilename=["testlog1.xml", "testlog2.xml"])
        @test isfile(joinpath(pwd(),"testlog1.xml"))
        @test isfile(joinpath(pwd(),"testlog2.xml"))
    end

    # Errors
    @test_throws ArgumentError TestReports.test([TEST_PKG.name, TEST_PKG.name]; logfilename=["testlog.xml"])
    @test_throws TypeError TestReports.test([TEST_PKG.name]; logfilename="ThisShouldBeInAnArray.xml")
    @test_throws TypeError TestReports.test(TEST_PKG.name; logfilename=["ThisShouldJustBeAString.xml"])

    # Tidy up
    Pkg.rm(TEST_PKG.name)
    rm.(joinpath.(Ref(pwd()), ["testlog.xml", "changedname.xml", "Example_testlog.xml", "PassingTests_testlog.xml", "testlog1.xml", "testlog2.xml"]))
    rm(new_path, recursive=true)
end

# clean up locally cached registry
rm(joinpath(@__DIR__, "registries"); force=true, recursive=true)
