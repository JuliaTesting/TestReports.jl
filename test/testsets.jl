using Dates
using Test
import Test: AbstractTestSet, Result, Pass, Fail, Broken, Error
using TestReports

@testset "handle_top_level_results!" begin
    # Simple top level resuls
    ts = @testset TestReportingTestSet "" begin
        @test 1 == 1
        @test 2 == 2
    end

    TestReports.handle_top_level_results!(ts)
    @test length(ts.results) == 1
    @test ts.results[1] isa AbstractTestSet
    @test length(ts.results[1].results) == 2
    @test all(isa.(ts.results[1].results, Result))

    # Mix of top level testset and results
    ts = @testset TestReportingTestSet "" begin
        @test 1 == 1
        @test 2 == 2
        @testset "Inner" begin
            @test 3 == 3
            @test 4 == 4
        end
    end 

    TestReports.handle_top_level_results!(ts)
    @test length(ts.results) == 2
    @test all(isa.(ts.results,  AbstractTestSet))
    @test length(ts.results[1].results) == 2
    @test all(isa.(ts.results[1].results, Result))
    @test length(ts.results[2].results) == 2
    @test all(isa.(ts.results[2].results, Result))
    @test ts.results[2].description == "Inner"

    # Testset only
    ts = @testset TestReportingTestSet "" begin
        @testset "Shouldn't Change" begin
            @test 1 == 1
            @test 2 == 2
        end
    end

    TestReports.handle_top_level_results!(ts)
    @test length(ts.results) == 1
    @test ts.results[1].description == "Shouldn't Change"
end

@testset "_flatten_results!" begin
    # Single nested test
    ts = @testset TestReportingTestSet "Nested" begin
        @testset "1" begin
            @testset "2" begin
                @testset "3" begin
                    @test 1 == 1
                end
            end
        end
    end
    flattened_results = TestReports._flatten_results!(ts)
    @test length(flattened_results) == 1
    @test flattened_results[1] isa AbstractTestSet
    @test flattened_results[1].description == "Nested/1/2/3"

    # Different level nested tests
    ts = @testset TestReportingTestSet "Nested" begin
        @testset "1" begin
            @testset "2" begin
                @testset "3" begin
                    @test 1 == 1
                end
                @test 2 == 2
            end
        end
    end
    flattened_results = TestReports._flatten_results!(ts)
    @test length(flattened_results) == 2
    @test all(isa.(flattened_results, AbstractTestSet))
    @test flattened_results[1].description == "Nested/1/2/3"
    @test flattened_results[2].description == "Nested/1/2"
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

    # Test for custom testsets (Issue #36)
    TestReports.add_to_ts_default!(ts_default, TestReportingTestSet(""))
    @test ts_default.results[end] isa TestReportingTestSet
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

@testset "Timing" begin
    # Test start time
    ts = @testset ReportingTestSet begin
        @test true
    end 
    @test ts.start_time <= Dates.now()

    # Unit test time
    duration = 0.2
    ts = @testset ReportingTestSet begin
        @test (sleep(duration); true)
        @test (sleep(duration); true)
    end 

    @test ts.results[1].time_taken >= Millisecond(duration * 1000)
    @test ts.results[2].time_taken >= Millisecond(duration * 1000)
    @test ts.time_taken >= ts.results[1].time_taken + ts.results[2].time_taken
end

@testset "Struct equality checks" begin
    # Equality
    result = Pass(:test, 0, 0, 0)
    res1 = TestReports.ReportingResult(result, Millisecond(0))
    res2 = TestReports.ReportingResult(result, Millisecond(1))
    @test res1 == res2
    @test hash(res1) == hash(res2)

    # Inequality
    result1 = Pass(:test, 0, 0, 0)
    result2 = Pass(:test, 0, 0, 1)
    res1 = TestReports.ReportingResult(result1, Millisecond(0))
    res2 = TestReports.ReportingResult(result2, Millisecond(0))
    @test res1 != res2
    @test hash(res1) != hash(res2)
end

@testset "Custom testsets" begin
    # Abstract methods
    ts = @testset TestReportingTestSet "" begin
        @test true
    end
    @test TestReports.time_taken(ts) == Dates.Millisecond(0)
    @test TestReports.start_time(ts) isa Dates.DateTime
    @test TestReports.hostname(ts) == gethostname()
    @test TestReports.set_time_taken!(ts, Dates.Millisecond(1)) === nothing
    @test TestReports.set_start_time!(ts, Dates.now()) === nothing
    @test TestReports.time_taken(ts.results[1]) == Dates.Millisecond(0)

    # Test Packages
    test_package_expected_pass("CustomTestSet") # Tests all abstract methods for accessing testset fields
    test_package_expected_fail("NoResultsCustomTestSet")
    test_package_expected_fail("NoDescriptionCustomTestSet")
end