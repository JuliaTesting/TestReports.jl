using Pkg
using Test
using TestReports

@testset "showerror" begin
    @test_throws TestReports.PkgTestError throw(TestReports.PkgTestError("Test"))
    @test sprint(showerror, TestReports.PkgTestError("Error text"), "") == "Error text"
end

@testset "TestReports compatibility" begin
    @test TestReports.compatible(v"0.0.1", "0.0.1")
    @test !TestReports.compatible(v"0.0.2", "0.0.1")
    @test !TestReports.compatible(v"0.0.1", "0.0.2")
    @test !TestReports.compatible(v"0.1.0", "0.0.1")
    @test !TestReports.compatible(v"0.0.1", "0.1.0")
    @test TestReports.compatible(v"0.1.0", "0.1.0")
    @test TestReports.compatible(v"0.1.1", "0.1.0")
    @test !TestReports.compatible(v"0.1.0", "0.1.1")
    @test !TestReports.compatible(v"0.1.0", "0.2.0")
    @test !TestReports.compatible(v"0.2.0", "0.1.0")
    @test !TestReports.compatible(v"1.0.0", "0.1.0")
    @test !TestReports.compatible(v"0.1.0", "1.0.0")
    @test TestReports.compatible(v"1.0.0", "1.0.0")
    @test TestReports.compatible(v"1.1.0", "1.0.0")
    @test TestReports.compatible(v"1.0.1", "1.0.0")
    @test !TestReports.compatible(v"1.0.1", "=1.0.0")
    @test !TestReports.compatible(v"1.1.0", "~1.0.0")
    @test !TestReports.compatible(v"1.0.0", "1.1.0")
    @test !TestReports.compatible(v"1.0.0", "1.0.1")

    test_package_expected_fail("OldTestReportsInTarget")
    test_package_expected_fail("OldTestReportsInDeps")
    test_package_expected_fail("OldDepInTarget")
    if VERSION >= v"1.2.0"
        test_package_expected_fail("OldTestReportsInTestDeps")
        test_package_expected_fail("OldDepInTestDeps")
        if VERSION >= v"1.7.0"
            test_package_expected_fail("OldTestReportsInTestManifest_1_7") # new manifest format
            test_package_expected_fail("OldDepInTestManifest_1_7") # new manifest format
        else
            test_package_expected_fail("OldTestReportsInTestManifest")
            test_package_expected_fail("OldDepInTestManifest")
        end
    end
end