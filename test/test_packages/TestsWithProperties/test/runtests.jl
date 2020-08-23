using Test
using TestReports
using Base.Threads

@testset "Math" begin
    recordproperty("File", "runtests.jl")

    @testset "Multiplication" begin
        recordproperty("ID", 1)
        @test 1*3 == 3
        @test 1*4 == 4
    end

    @test 4 % 2 == 0
    @test 16 == 16

    @testset "addition" begin
        recordproperty("ID", 2)
        @test 1+1 == 2
        @test 1+4 == 5

        @testset "negative addition" begin
            recordproperty("AdditionalNest", true)
            @test 1 + -1 == 0
            @test 10 + -5 == 5
        end
    end
end

@testset "Types" begin
    recordproperty("String", "TextTests")
    recordproperty("Int", 1) 
    recordproperty("Float", 0.5) 
    recordproperty("List", ["1"]) 
    recordproperty("Symbol", :asymbol) 
    @test occursin("i", "in")
end