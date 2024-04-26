using Test
using TestReports
using Base.Threads

@testset "Outer" begin
    record_testset_property("File", "runtests.jl")

    @testset "Middle 1" begin
        record_testset_property("ID", 1)
        @test true
    end

    @test true

    @testset "Middle 2" begin
        record_testset_property("ID", 2)
        @test true

        @testset "Inner" begin
            record_testset_property("AdditionalNest", true)
        end
    end

    @testset "Middle 3" begin
        record_test_property("ID", 3)
        @test true

        @testset "Inner" begin
            record_test_property("AdditionalNest", true)
        end
    end
end

@testset "Types" begin
    record_testset_property("String", "TextTests")
    record_testset_property("Int", 1)
    record_testset_property("Float", 0.5)
    record_testset_property("List", ["1"])
    record_testset_property("Symbol", :asymbol)
    @test true
end
