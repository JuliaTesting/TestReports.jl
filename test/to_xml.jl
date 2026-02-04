
struct CustomException <: Exception end

@testset "get_error_info" begin
    @testset "type" begin
        # Argument error in test
        ts = @testset ReportingTestSet begin 
            @test throw(ArgumentError("Error"))
        end
        err = ts.results[1].result
        _, type, _ = TestReports.get_error_info(err)
        @test type == "ArgumentError" 

        # Argument error outside of test
        ts = @testset ReportingTestSet begin 
            throw(ArgumentError("Error"))
        end
        err = ts.results[1].result
        _, type, _ = TestReports.get_error_info(err)
        @test type == "ArgumentError" 

        # Process error in test
        ts = @testset ReportingTestSet begin 
            @test run(`false`)
        end
        err = ts.results[1].result
        _, type, _ = TestReports.get_error_info(err)
        if VERSION < v"1.2"
            @test type == "ErrorException" 
        else
            @test type == "ProcessFailedException" 
        end

        # Custom exception
        ts = @testset ReportingTestSet begin 
            throw(CustomException())
        end
        err = ts.results[1].result
        _, type, _ = TestReports.get_error_info(err)
        @test type == "CustomException" 
    end
end

@testset "to_xml" begin
    result = Pass(:null, :orig_expr, nothing, nothing)
    node, _, _, _ = TestReports.to_xml(result)
    @test node.name == "testcase"

    result = Fail(:test, :orig_expr, nothing, nothing, LineNumberNode(1))
    node, _, _, _ = TestReports.to_xml(result)
    @test node.name == "testcase"

    result = Broken(:null, :orig_expr)
    node, _, _, _ = TestReports.to_xml(result)
    @test node.name == "testcase"

    result = Error(:test_nonbool, :orig_expr, nothing, nothing, LineNumberNode(1))
    node, _, _, _ = TestReports.to_xml(result)
    @test node.name == "testcase"


    struct WeirdFailure <: Result
        orig_expr
        source::LineNumberNode
        some_nonsense
    end
    result = WeirdFailure(:orig_expr, LineNumberNode(1), 3.1415)
    node, _, _, _ = TestReports.to_xml(result)
    @test node.name == "testcase"
    
end

function record(ts::DefaultTestSet, t::LogTestFailure)

end
