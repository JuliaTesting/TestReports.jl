using Pkg
using ReferenceTests
using UUIDs
using Test
using TestReports

const TEST_PKG = (name = "Example", uuid = UUID("7876af07-990d-54b4-ab0e-23690620f79a"))

@testset "SingleNest" begin
    @test_reference "references/singlenest.txt" read(`$(Base.julia_cmd()) -e "using Test; using TestReports; (@testset ReportingTestSet \"blah\" begin @testset \"a\" begin @test 1 ==1 end end) |> report |> print"`, String) |>  clean_output
end

@testset "Complex Example" begin
    @test_reference "references/complexexample.txt" read(`$(Base.julia_cmd()) $(@__DIR__)/example.jl`, String) |> clean_output
end

@testset "Runner tests" begin
    @testset "Installed packages by name in primary environment" begin
        # Pkg.add
        Pkg.add(TEST_PKG.name)
        test_successful_testrun(() -> TestReports.test(TEST_PKG.name), TEST_PKG.name)
        Pkg.rm(TEST_PKG.name)
        @test_throws TestReports.PkgTestError TestReports.test(TEST_PKG.name)

        # Pkg.develop
        pkgname = "PassingTests"
        Pkg.develop(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
        test_successful_testrun(() -> TestReports.test(pkgname), pkgname)
        Pkg.rm("PassingTests")
    end

    @testset "Activated projects - TestReports in stacked environment" begin
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

    @testset "Non-package error in runner" begin
        temp_pkg_dir() do tmp
            pkgname = "PassingTests"
            Pkg.develop(Pkg.PackageSpec(path=joinpath(@__DIR__, "test_packages", pkgname)))
            # Pass non-existing argument to julia to make run command fail
            @test_throws TestReports.PkgTestError TestReports.test(pkgname, julia_args=`--doesnt-exist`)
        end
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
    Pkg.rm(TEST_PKG.name)

    # Multiple package test
    temp_pkg_dir() do tmp
        copy_test_package(tmp, "PassingTests")
        Pkg.activate(tmp)
        Pkg.develop(Pkg.PackageSpec(path=joinpath(tmp, "PassingTests")))
        Pkg.add(TEST_PKG.name)
        TestReports.test([TEST_PKG.name, "PassingTests"])
        @test isfile(joinpath(pwd(),"Example_testlog.xml"))
        @test isfile(joinpath(pwd(),"PassingTests_testlog.xml"))
        TestReports.test([TEST_PKG.name, "PassingTests"]; logfilename=["testlog1.xml", "testlog2.xml"])
        @test isfile(joinpath(pwd(),"testlog1.xml"))
        @test isfile(joinpath(pwd(),"testlog2.xml"))
        Pkg.rm("PassingTests")
        Pkg.rm(TEST_PKG.name)
    end

    # Errors
    @test_throws ArgumentError TestReports.test([TEST_PKG.name, TEST_PKG.name]; logfilename=["testlog.xml"])
    @test_throws TypeError TestReports.test([TEST_PKG.name]; logfilename="ThisShouldBeInAnArray.xml")
    @test_throws TypeError TestReports.test(TEST_PKG.name; logfilename=["ThisShouldJustBeAString.xml"])

    # Tidy up
    rm.(joinpath.(Ref(pwd()), ["testlog.xml", "changedname.xml", "Example_testlog.xml", "PassingTests_testlog.xml", "testlog1.xml", "testlog2.xml"]))
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

@testset "report - check_ts_structure" begin
    # No top level testset
    ts = @testset TestReportingTestSet begin
        @test true
    end
    @test_throws ArgumentError TestReports.check_ts_structure(ts)

    # Not flattened
    ts = @testset TestReportingTestSet begin
        @testset TestReportingTestSet begin
            @test true
            @testset TestReportingTestSet begin
                @test true
            end
        end
    end
    @test_throws ArgumentError TestReports.check_ts_structure(ts)

    # Correct structure
    ts = @testset TestReportingTestSet begin
        @testset TestReportingTestSet begin
            @test true
        end
    end
    @test TestReports.check_ts_structure(ts) isa Any # Doesn't error
end
