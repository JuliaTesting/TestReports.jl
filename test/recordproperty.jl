using EzXML
using Test
import Test: DefaultTestSet, AbstractTestSet, finish, record, get_testset_depth, get_testset
using ReferenceTests
using TestReports

mutable struct NoPropsReportingTestSet <: AbstractTestSet
    description::AbstractString
    results::Vector
end
NoPropsReportingTestSet(desc) = NoPropsReportingTestSet(desc, [])
NoPropsReportingTestSet(desc, results) = NoPropsReportingTestSet(desc, result)
record(ts::NoPropsReportingTestSet, t) = (push!(ts.results, t); t)
function finish(ts::NoPropsReportingTestSet)
    if get_testset_depth() != 0
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end
end

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
                @test 1 == 1
            end
            @testset begin
                recordproperty("Prop", "Inner 2")
                @test 2 == 2
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
                    @test 1 == 1
                end
                @testset begin
                    recordproperty("Prop", "Inner 2")
                    @test 2 == 2
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
            copy_test_package(tmp, pkg)
            Pkg.activate(joinpath(tmp, pkg))
            TestReports.test(pkg)
        end
        logfile = joinpath(@__DIR__, "testlog.xml")
        @test_reference "references/test_with_properties.txt" open(f->read(f, String), logfile) |> clean_report
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
        @test ts.results[1].results[1] isa Error

        # Test warning (when finishing ts) for parent ID being overwritten by child
        ts = @testset ReportingTestSet "" begin
            @testset ReportingTestSet "Outer" begin
                recordproperty("ID", "42")
                @testset ReportingTestSet "Inner" begin
                    recordproperty("ID", "0")
                    @test 1==1
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
                @testset NoPropsReportingTestSet "Inner" begin
                    @test 1==1
                end
            end
        end
        # Force flattening as ts doesn't finish fully as it is not the top level testset
        fail_text = r"Properties of testset Outer can not be added to child testset Inner as it is not a ReportingTestSet."
        @test_logs (:warn, fail_text) TestReports.flatten_results!(ts)
    end

    @testset "Check no interference with default test set" begin
        recordproperty("Nothing", "WillHappen")
    end
end