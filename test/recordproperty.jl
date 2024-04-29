@testset "recordproperty" begin
    @testset "Property recording" begin
        # Test for blanks in properties if nothing given 
        ts = @testset ReportingTestSet "" begin end
        @test length(keys(ts.properties)) == 0

        # Test property with different types updated in testset
        ts = @testset ReportingTestSet "" begin recordproperty("ID", "1") end
        @test ts.properties["ID"] == "1"
        ts = @testset ReportingTestSet "" begin recordproperty("ID", 1) end
        @test ts.properties["ID"] == 1

        # Test nested testset
        ts = @testset ReportingTestSet "" begin
            recordproperty("ID", "TopLevel")
            @testset begin
                recordproperty("Prop", "Inner 1")
            end
            @testset begin
                recordproperty("Prop", "Inner 2")
            end
        end
        @test ts.properties["ID"] == "TopLevel"
        @test ts.results[1].properties["Prop"] == "Inner 1"
        @test ts.results[2].properties["Prop"] == "Inner 2"
    end

    # Test properties in report
    @testset "Report generation" begin
        # Check properties in XML doc variable
        ts = @testset ReportingTestSet "MimicRunner" begin
            @testset "TopLevel" begin
                recordproperty("ID", "TopLevel")
                @testset begin
                    recordproperty("Prop", "Inner 1")
                end
                @testset begin
                    recordproperty("Prop", "Inner 2")
                end
            end
        end
        ts = TestReports.flatten_results!(ts)  # Force flattening, as "finish" sees that ts is not top level
        rep = report(ts)
        properties_nodes = lastnode.(elements(root(rep)))

        # Child properties are first in report
        @test elements(properties_nodes[1])[1]["name"] == "Prop"
        @test elements(properties_nodes[1])[1]["value"] == "Inner 1"
        @test elements(properties_nodes[1])[2]["name"] == "ID"
        @test elements(properties_nodes[1])[2]["value"] == "TopLevel"
        @test elements(properties_nodes[2])[1]["name"] == "Prop"
        @test elements(properties_nodes[2])[1]["value"] == "Inner 2"
        @test elements(properties_nodes[2])[2]["name"] == "ID"
        @test elements(properties_nodes[2])[2]["value"] == "TopLevel"

        # Test full packaage
        pkg = "TestsWithProperties"
        temp_pkg_dir() do tmp
            Pkg.develop(Pkg.PackageSpec(path=test_package_path(pkg)))
            TestReports.test(pkg)
        end
        logfile = joinpath(@__DIR__, "testlog.xml")
        test_file = VERSION >= v"1.7.0" ? "references/test_with_properties.txt" : "references/test_with_properties_pre_1_7.txt"
        @test_reference test_file open(f->read(f, String), logfile) |> clean_output
    end

    # Test for warning when ID set twice
    @testset "warnings & errors" begin

        # Test error in testset when setting duplicate property name
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Parent" begin
                recordproperty("ID", "42")
                recordproperty("ID", "42")
            end
        end
        @test ts.results[1].results[1] isa TestReports.ReportingResult{Error}

        # Test warning (when finishing ts) for parent ID being overwritten by child
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                recordproperty("ID", "42")
                @testset ReportingTestSet "Inner" begin
                    recordproperty("ID", "0")
                end
            end
        end
        # Force flattening as ts doesn't finish fully as it is not the top level testset
        overwrite_text = "Property ID in testest Outer overwritten by child testset Inner"
        @test_logs (:warn, overwrite_text) TestReports.flatten_results!(ts)
        @test ts.results[1].properties["ID"] == "0"

        # Test for parent testset properties not being applied to child due to different type
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                recordproperty("ID", "42")
                @testset TestReportingTestSet "Inner" begin
                    @test 1 == 1
                end
            end
        end
        # Force flattening as ts doesn't finish fully as it is not the top level testset
        fail_text = r"Properties of testset Outer can not be added to child testset Inner as it does not have a TestReports.properties method defined."
        @test_logs (:warn, fail_text) TestReports.flatten_results!(ts)

        # Test for ReportingTestSet setting a property inside of a parent custom testset
        ts = @testset ReportingTestSet "TestReports Wrapper" begin
            @testset TestReportingTestSet "Custom" begin
                ts = @testset ReportingTestSet "Inner" begin
                    recordproperty("ID", "42")
                    @test 1 == 1
                end
            end
        end
        # Force flattening as ts doesn't finish fully as it is not the top level testset
        TestReports.flatten_results!(ts)
        @test ts.results[1].properties["ID"] == "42"

        # Error if attempting to add property to AbstractTestSet which has properties field with wrong type
        ts = @testset WrongPropsTestSet begin; recordproperty("id",1); end
        @test eval(Meta.parse(ts.results[1].value)) isa TestReports.PkgTestError
        @test occursin("properties method for custom testset must return a dictionary", eval(Meta.parse(ts.results[1].value)).msg)
    end

    @testset "Check no interference with default test set" begin
        recordproperty("Nothing", "WillHappen")
    end
end
