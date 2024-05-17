@testset "recordproperty / properties" begin
    using TestReports: properties

    @testset "empty" begin
        ts = @testset ReportingTestSet begin end
        @test properties(ts) isa AbstractVector
        @test length(properties(ts)) == 0

        ts = @testset "_" begin end
        @test properties(ts) === nothing
    end

    @testset "record property" begin
        ts = @testset ReportingTestSet begin
            recordproperty("tested-item-id", "SAMD-45")
        end
        @test properties(ts) == ["tested-item-id" => "SAMD-45"]

        ts = @testset ReportingTestSet begin
            recordproperty("count", 3)
        end
        @test properties(ts) == ["count" => 3]
    end

    @testset "multiple properties" begin
        ts = @testset ReportingTestSet begin
            recordproperty("tests", "ABC-789")
            recordproperty("tests", "ABC-1011")
        end
        @test properties(ts) == ["tests" => "ABC-789", "tests" => "ABC-1011"]

        ts = @testset ReportingTestSet begin
            recordproperty("tests", "ABC-789")
            recordproperty("tests", "ABC-789")
        end
        @test properties(ts) == ["tests" => "ABC-789", "tests" => "ABC-789"]
    end

    @testset "nested properties" begin
        ts = @testset ReportingTestSet begin
            recordproperty("tests", "ABC-789")
            @testset begin
                recordproperty("tests", "ABC-1011")
            end
        end
        @test properties(ts) == ["tests" => "ABC-789"]
        @test properties(ts.results[1]) == ["tests" => "ABC-1011"]

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test properties(flattened_testsets[1]) == ["tests" => "ABC-789"]
        @test properties(flattened_testsets[2]) == ["tests" => "ABC-789", "tests" => "ABC-1011"]

        ts = @testset ReportingTestSet begin
            recordproperty("tests", "ABC-789")
            @testset begin
                recordproperty("tests", "ABC-789")
            end
            @testset begin
            end
        end
        @test properties(ts) == ["tests" => "ABC-789"]
        @test properties(ts.results[1]) == ["tests" => "ABC-789"]
        @test properties(ts.results[2]) == []

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test properties(flattened_testsets[1]) == ["tests" => "ABC-789"]
        @test properties(flattened_testsets[2]) == ["tests" => "ABC-789", "tests" => "ABC-789"]
    end

    @testset "custom testset support" begin
        # Test for parent testset properties not being applied to child due to different type
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                recordproperty("ID", "42")
                @testset TestReportingTestSet "Inner" begin
                    @test 1 == 1
                end
            end
        end
        fail_text = "Properties of testset \"Outer\" can not be added to child testset \"Inner\" as it does not have a `TestReports.properties` method defined."
        flattened_testsets = @test_logs (:warn, fail_text) TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test properties(flattened_testsets[1]) == ["ID" => "42"]
        @test properties(flattened_testsets[2]) === nothing

        # Test for ReportingTestSet setting a property inside of a parent custom testset
        ts = @testset ReportingTestSet "TestReports Wrapper" begin
            @testset TestReportingTestSet "Custom" begin
                ts = @testset ReportingTestSet "Inner" begin
                    recordproperty("ID", "42")
                    @test 1 == 1
                end
            end
        end
        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test properties(flattened_testsets[1]) == ["ID" => "42"]
    end

    @testset "ignore properties on unsupported test sets" begin
        ts = @testset begin
            recordproperty("id", 1)
        end
        @test properties(ts) === nothing
    end

    @testset "junit report" begin
        # Check properties in XML doc variable
        ts = @testset ReportingTestSet "TopLevel" begin
            recordproperty("ID", "TopLevel")
            @testset begin
                recordproperty("Prop", "Inner 1")
            end
            @testset begin
                recordproperty("Prop", "Inner 2")
            end
        end
        rep = report(ts)
        testsuite_elements = findall("//testsuite", root(rep))
        @test length(testsuite_elements) == 3

        # Child properties are first in report
        testsuite_property_elements = findall("properties/property", testsuite_elements[1])
        @test length(testsuite_property_elements) == 1
        @test testsuite_property_elements[1]["name"] == "ID"
        @test testsuite_property_elements[1]["value"] == "TopLevel"

        testsuite_property_elements = findall("properties/property", testsuite_elements[2])
        @test length(testsuite_property_elements) == 2
        @test testsuite_property_elements[1]["name"] == "ID"
        @test testsuite_property_elements[1]["value"] == "TopLevel"
        @test testsuite_property_elements[2]["name"] == "Prop"
        @test testsuite_property_elements[2]["value"] == "Inner 1"

        testsuite_property_elements = findall("properties/property", testsuite_elements[3])
        @test length(testsuite_property_elements) == 2
        @test testsuite_property_elements[1]["name"] == "ID"
        @test testsuite_property_elements[1]["value"] == "TopLevel"
        @test testsuite_property_elements[2]["name"] == "Prop"
        @test testsuite_property_elements[2]["value"] == "Inner 2"
    end
end
