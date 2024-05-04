using Test
using TestReports
using Base.Threads

@testset "Outer" begin
    recordproperty("File", "runtests.jl")

    @testset "Middle 1" begin
        recordproperty("ID", 1)
        @test true
    end

    @test true

    @testset "Middle 2" begin
        recordproperty("ID", 2)
        @test true

        @testset "Inner" begin
            recordproperty("ID", 3)
            recordproperty("AdditionalNest", true)
        end
    end
end

@testset "Types" begin
    recordproperty("String", "TextTests")
    recordproperty("Int", 1) 
    recordproperty("Float", 0.5) 
    recordproperty("List", ["1"]) 
    recordproperty("Symbol", :asymbol) 
    @test true
end
