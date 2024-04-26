@testset "record_testset_property / testset_properties" begin
    using TestReports: testset_properties

    @testset "empty" begin
        ts = @testset ReportingTestSet begin end
        @test testset_properties(ts) isa AbstractSet
        @test length(testset_properties(ts)) == 0

        ts = @testset "_" begin end
        @test testset_properties(ts) === nothing
    end

    @testset "record property" begin
        ts = @testset ReportingTestSet begin
            record_testset_property("tested-item-id", "SAMD-45")
        end
        @test testset_properties(ts) == Set(["tested-item-id" => "SAMD-45"])

        ts = @testset ReportingTestSet begin
            record_testset_property("count", 3)
        end
        @test testset_properties(ts) == Set(["count" => 3])
    end

    @testset "multiple properties" begin
        ts = @testset ReportingTestSet begin
            record_testset_property("tests", "ABC-789")
            record_testset_property("tests", "ABC-1011")
        end
        @test testset_properties(ts) == Set(["tests" => "ABC-789", "tests" => "ABC-1011"])

        ts = @testset ReportingTestSet begin
            record_testset_property("tests", "ABC-789")
            record_testset_property("tests", "ABC-789")
        end
        @test testset_properties(ts) == Set(["tests" => "ABC-789"])
    end

    @testset "nested properties" begin
        ts = @testset ReportingTestSet begin
            record_testset_property("tests", "ABC-789")
            @testset begin
                record_testset_property("tests", "ABC-1011")
            end
        end
        @test testset_properties(ts) == Set(["tests" => "ABC-789"])
        @test testset_properties(ts.results[1]) == Set(["tests" => "ABC-1011"])

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test testset_properties(flattened_testsets[1]) == Set(["tests" => "ABC-789"])
        @test testset_properties(flattened_testsets[2]) == Set(["tests" => "ABC-789", "tests" => "ABC-1011"])

        ts = @testset ReportingTestSet begin
            record_testset_property("tests", "ABC-789")
            @testset begin
                record_testset_property("tests", "ABC-789")
            end
            @testset begin
            end
        end
        @test testset_properties(ts) == Set(["tests" => "ABC-789"])
        @test testset_properties(ts.results[1]) == Set(["tests" => "ABC-789"])
        @test testset_properties(ts.results[2]) == Set()

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test testset_properties(flattened_testsets[1]) == Set(["tests" => "ABC-789"])
        @test testset_properties(flattened_testsets[2]) == Set(["tests" => "ABC-789"])
    end

    @testset "custom testset support" begin
        # Test for parent testset properties not being applied to child due to different type
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                record_testset_property("ID", "42")
                @testset TestReportingTestSet "Inner" begin
                    @test 1 == 1
                end
            end
        end
        fail_text = "Properties of testset \"Outer\" can not be added to child testset \"Inner\" as it does not have a `TestReports.testset_properties` method defined."
        flattened_testsets = @test_logs (:warn, fail_text) TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test testset_properties(flattened_testsets[1]) == Set(["ID" => "42"])
        @test testset_properties(flattened_testsets[2]) === nothing

        # Test for ReportingTestSet setting a property inside of a parent custom testset
        ts = @testset ReportingTestSet "TestReports Wrapper" begin
            @testset TestReportingTestSet "Custom" begin
                ts = @testset ReportingTestSet "Inner" begin
                    record_testset_property("ID", "42")
                    @test 1 == 1
                end
            end
        end
        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test testset_properties(flattened_testsets[1]) == Set(["ID" => "42"])
    end

    @testset "ignore properties on unsupported test sets" begin
        ts = @testset begin
            record_testset_property("id", 1)
        end
        @test testset_properties(ts) === nothing
    end

    @testset "junit report" begin
        # Check properties in XML doc variable
        ts = @testset ReportingTestSet "TopLevel" begin
            record_testset_property("ID", "TopLevel")
            @testset begin
                record_testset_property("Prop", "Inner 1")
            end
            @testset begin
                record_testset_property("Prop", "Inner 2")
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
        @test testsuite_property_elements[1]["name"] == "Prop"
        @test testsuite_property_elements[1]["value"] == "Inner 1"
        @test testsuite_property_elements[2]["name"] == "ID"
        @test testsuite_property_elements[2]["value"] == "TopLevel"

        testsuite_property_elements = findall("properties/property", testsuite_elements[3])
        @test length(testsuite_property_elements) == 2
        @test testsuite_property_elements[1]["name"] == "Prop"
        @test testsuite_property_elements[1]["value"] == "Inner 2"
        @test testsuite_property_elements[2]["name"] == "ID"
        @test testsuite_property_elements[2]["value"] == "TopLevel"
    end
end

@testset "record_test_property / test_properties" begin
    using TestReports: test_properties

    @testset "empty" begin
        ts = @testset ReportingTestSet begin end
        @test test_properties(ts) isa AbstractSet
        @test length(test_properties(ts)) == 0

        ts = @testset "_" begin end
        @test test_properties(ts) === nothing
    end

    @testset "record property" begin
        ts = @testset ReportingTestSet begin
            record_test_property("tested-item-id", "SAMD-45")
        end
        @test test_properties(ts) == Set(["tested-item-id" => "SAMD-45"])

        ts = @testset ReportingTestSet begin
            record_test_property("count", 3)
        end
        @test test_properties(ts) == Set(["count" => 3])
    end

    @testset "flattening eliminates testsets without tests" begin
        ts = @testset ReportingTestSet begin
            record_test_property("tested-item-id", "SAMD-45")
        end
        flattened_testsets = TestReports.flatten_results!(ts)
        @test isempty(flattened_testsets)

        ts = @testset ReportingTestSet begin
            record_test_property("tested-item-id", "SAMD-45")
            @test true
        end
        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test test_properties(flattened_testsets[1]) == Set(["tested-item-id" => "SAMD-45"])
    end

    @testset "multiple properties" begin
        ts = @testset ReportingTestSet begin
            record_test_property("tests", "ABC-789")
            record_test_property("tests", "ABC-1011")
        end
        @test test_properties(ts) == Set(["tests" => "ABC-789", "tests" => "ABC-1011"])

        ts = @testset ReportingTestSet begin
            record_test_property("tests", "ABC-789")
            record_test_property("tests", "ABC-789")
        end
        @test test_properties(ts) == Set(["tests" => "ABC-789"])
    end

    @testset "nested properties" begin
        ts = @testset ReportingTestSet begin
            record_test_property("tests", "ABC-789")
            @testset begin
                record_test_property("tests", "ABC-1011")
                @test true
            end
        end
        @test test_properties(ts) == Set(["tests" => "ABC-789"])
        @test test_properties(ts.results[1]) == Set(["tests" => "ABC-1011"])

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test test_properties(flattened_testsets[1]) == Set(["tests" => "ABC-789", "tests" => "ABC-1011"])

        ts = @testset ReportingTestSet begin
            record_test_property("tests", "ABC-789")
            @testset begin
                record_test_property("tests", "ABC-789")
                @test true
            end
            @testset begin
                @test true
            end
        end
        @test test_properties(ts) == Set(["tests" => "ABC-789"])
        @test test_properties(ts.results[1]) == Set(["tests" => "ABC-789"])
        @test test_properties(ts.results[2]) == Set()

        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 2
        @test test_properties(flattened_testsets[1]) == Set(["tests" => "ABC-789"])
        @test test_properties(flattened_testsets[2]) == Set(["tests" => "ABC-789"])
    end

    @testset "custom testset support" begin
        # Test for parent testset properties not being applied to child due to different type
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                record_test_property("ID", "42")
                @testset TestReportingTestSet "Inner" begin
                    @test 1 == 1
                end
            end
        end
        fail_text = "Properties of testset \"Outer\" can not be added to child testset \"Inner\" as it does not have a `TestReports.test_properties` method defined."
        flattened_testsets = @test_logs (:warn, fail_text) TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test testset_properties(flattened_testsets[1]) === nothing

        # Test for ReportingTestSet setting a property inside of a parent custom testset
        ts = @testset ReportingTestSet "TestReports Wrapper" begin
            @testset TestReportingTestSet "Custom" begin
                ts = @testset ReportingTestSet "Inner" begin
                    record_test_property("ID", "42")
                    @test 1 == 1
                end
            end
        end
        flattened_testsets = TestReports.flatten_results!(ts)
        @test length(flattened_testsets) == 1
        @test test_properties(flattened_testsets[1]) == Set(["ID" => "42"])
    end

    @testset "ignore properties on unsupported test sets" begin
        ts = @testset begin
            record_test_property("id", 1)
        end
        @test test_properties(ts) === nothing
    end

    @testset "junit report" begin
        # Check properties in XML doc variable
        ts = @testset ReportingTestSet "TopLevel" begin
            record_test_property("ID", "TopLevel")
            @testset begin
                record_test_property("Prop", "Inner 1")
                @test true
            end
            @testset begin
                record_test_property("Prop", "Inner 2")
                @test true
            end
        end
        rep = report(ts)
        testsuite_elements = findall("//testsuite", root(rep))
        @test length(testsuite_elements) == 2

        # Child properties are first in report
        testcase_property_nodes = findall("testcase/properties/property", testsuite_elements[1])
        @test length(testcase_property_nodes) == 2
        @test testcase_property_nodes[1]["name"] == "Prop"
        @test testcase_property_nodes[1]["value"] == "Inner 1"
        @test testcase_property_nodes[2]["name"] == "ID"
        @test testcase_property_nodes[2]["value"] == "TopLevel"

        testcase_property_nodes = findall("testcase/properties/property", testsuite_elements[2])
        @test length(testcase_property_nodes) == 2
        @test testcase_property_nodes[1]["name"] == "Prop"
        @test testcase_property_nodes[1]["value"] == "Inner 2"
        @test testcase_property_nodes[2]["name"] == "ID"
        @test testcase_property_nodes[2]["value"] == "TopLevel"
    end
end
