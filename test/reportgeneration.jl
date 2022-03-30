using Pkg
using ReferenceTests
using UUIDs
using Test
using TestReports

const TEST_PKG = (name = "Example", uuid = UUID("7876af07-990d-54b4-ab0e-23690620f79a"))

@testset "SingleNest" begin
    test_file = VERSION >= v"1.7.0" ? "references/singlenest.txt" : "references/singlenest_pre_1_7.txt"
    @test_reference test_file read(`$(Base.julia_cmd()) -e "using Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`, String) |>  clean_output
end

@testset "Complex Example" begin
    test_file = VERSION >= v"1.7.0" ? "references/complexexample.txt" : "references/complexexample_pre_1_7.txt"
    @test_reference test_file read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> clean_output
end

@testset "Runner tests" begin
    @testset "Installed packages by name in primary environment" begin
        # For speed avoid updating registry, we have a fresh one anyway
        Pkg.UPDATED_REGISTRY_THIS_SESSION[] = true
        # Pkg.add test
        Pkg.add(TEST_PKG.name)
        test_successful_testrun(() -> TestReports.test(TEST_PKG.name), TEST_PKG.name)
        Pkg.rm(TEST_PKG.name)
        @test_throws TestReports.PkgTestError TestReports.test(TEST_PKG.name)
    end

    @testset "Activated projects - TestReports in stacked environment" begin
        @testset "by name" begin
            # The test run should not fail when passed the name of the project
            # that is activated and fail when its deactivated
            temp_pkg_dir() do tmp
                pkg = "PassingTests"
                path = copy_test_package(tmp, pkg)
                Pkg.activate(path)
                test_successful_testrun(() -> TestReports.test(pkg), pkg)
            end
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

    @testset "Non-package error in runner" begin
        temp_pkg_dir() do tmp
            pkg = "PassingTests"
            Pkg.develop(Pkg.PackageSpec(path=test_package_path(pkg)))
            # Pass non-existing argument to julia to make run command fail
            @test_throws TestReports.PkgTestError TestReports.test(pkg, julia_args=`--doesnt-exist`)
        end
    end
end

@testset "Test packages" begin
    # Errors
    test_package_expected_fail("FailedTest")
    test_package_expected_fail("ErroredTest")
    test_package_expected_fail("NoTestFile")

    # Various test dependencies
    test_pkgs = [
        "TestsWithDeps",
        "TestsWithTestDeps"
    ]
    foreach(test_package_expected_pass, test_pkgs)

    # Test file project file tests, 1.2 and above
    @static if VERSION >= v"1.2.0"
        test_pkgs = [
            "TestsWithProjectFile",
            "TestsWithProjectFileWithTestDeps"
        ]
        foreach(test_package_expected_pass, test_pkgs)
    end

    # Test arguments
    temp_pkg_dir() do tmp
        pkg = "TestArguments"
        Pkg.develop(Pkg.PackageSpec(path=test_package_path(pkg)))
        test_successful_testrun(() -> TestReports.test(pkg; test_args=`a b`, julia_args=`--quiet --check-bounds=no`), pkg)
        test_successful_testrun(() -> TestReports.test(pkg; test_args=["a", "b"], julia_args=`--quiet --check-bounds=no`), pkg)
    end
end

@testset "logfile options" begin
    Pkg.add(TEST_PKG.name)

    # Single package tests
    TestReports.test(TEST_PKG.name)
    @test isfile(joinpath(pwd(),"testlog.xml"))
    new_path = joinpath(pwd(), "NonExistentDir")
    TestReports.test(TEST_PKG.name; logfilename="changedname.xml", logfilepath=new_path)
    @test isfile(joinpath(new_path,"changedname.xml"))
    Pkg.rm(TEST_PKG.name)

    # Multiple package test
    temp_pkg_dir() do tmp
        Pkg.develop(Pkg.PackageSpec(path=test_package_path("PassingTests")))
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
    rm.(joinpath.(Ref(pwd()), ["testlog.xml", "Example_testlog.xml", "PassingTests_testlog.xml", "testlog1.xml", "testlog2.xml"]))
    rm(new_path, recursive=true)
end

@testset "Chained failing test - Issue #25" begin
    ts = @testset ReportingTestSet begin
        ts = @testset ReportingTestSet begin
            @test 1==1 && 1==0
        end
    end
    @test report(ts) isa Any  # Would fail before #25
end

@testset "report - check_ts" begin
    # No top level testset
    ts = @testset TestReportingTestSet begin
        @test true
    end
    @test_throws ArgumentError TestReports.check_ts(ts)

    # Not flattened
    ts = @testset TestReportingTestSet begin
        @testset TestReportingTestSet begin
            @test true
            @testset TestReportingTestSet begin
                @test true
            end
        end
    end
    @test_throws ArgumentError TestReports.check_ts(ts)

    # No description field
    ts = @testset TestReportingTestSet begin
        @testset NoDescriptionTestSet begin
            @test true
        end
    end
    @test_throws ErrorException TestReports.check_ts(ts)

    # No results field
    ts = @testset TestReportingTestSet begin
        @testset NoResultsTestSet begin
            @test true
        end
    end
    @test_throws ErrorException TestReports.check_ts(ts)

    # Correct structure
    ts = @testset TestReportingTestSet begin
        @testset TestReportingTestSet begin
            @test true
        end
    end
    @test TestReports.check_ts(ts) isa Any # Doesn't error
end

@testset "Error counting - Issue #72" begin
    ts = @testset ReportingTestSet begin
        @testset "nontest_error" begin
            variableThatDoNotExits # No test here so shouldn't count
        end
        @testset "test_error" begin
            @test variableThatDoNotExits == 42     
        end
        @testset "test_unbroken" begin
            @test_broken true
        end
        @testset "test_nonbool" begin
            @test 1
        end
    end
    flattened_ts = TestReports.flatten_results!(ts)

    # Test individual Errors
    _, _, ntest = TestReports.get_error_info(ts.results[1].results[1].result)
    @test ntest == 0
    _, _, ntest = TestReports.get_error_info(ts.results[2].results[1].result)
    @test ntest == 1
    _, _, ntest = TestReports.get_error_info(ts.results[3].results[1].result)
    @test ntest == 1
    _, _, ntest = TestReports.get_error_info(ts.results[4].results[1].result)
    @test ntest == 1
    
    # Test total numbers
    xdoc = report(ts)
    attrs = attributes(elements(xdoc.node)[1])
    for attr in attrs
        if attr.name == "errors"
            @test attr.content == "4"
        elseif attr.name == "tests"
            @test attr.content == "3"
        end
    end

    # Test unknown test_type field
    @test_throws TestReports.PkgTestError TestReports.get_error_info(Error(Symbol(),nothing,nothing,nothing,LineNumberNode(1)))
end