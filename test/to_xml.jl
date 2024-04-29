
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
        @test type == "ProcessFailedException"

        # Custom exception
        ts = @testset ReportingTestSet begin 
            throw(CustomException())
        end
        err = ts.results[1].result
        _, type, _ = TestReports.get_error_info(err)
        @test type == "CustomException" 
    end
end
