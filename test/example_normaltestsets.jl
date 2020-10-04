using Test
using Base.Threads

@testset "Math" begin

    @testset "Multiplication" begin
        @test 1*3 == 3
        @test 1*2 == 5 # wrong
        @test 1*4 == 4
    end

    @test 4 % 2 == 0
    @test sqrt(20) == 5 # wrong
    @test 16 == 16

    @testset "addition" begin
        @test 1+1 == 2
        @test 1+2 == 5 # wrong
        @test 1+4 == 5

        @testset "negative addition" begin
            @test 1 + -1 == 0
            @test 1 + -2 == 1 #wrong
            @test 10 + -5 == 5
        end
    end

    @testset "other" begin
        @test_broken sqrt(-1)
        @test 1/0 # not a real test
        @test 1 == error("Nooo") # error
        @test 1 == rand(2,2)\rand(4,4) # deep error
        @test_broken true

    end

    @testset "Error outside of tests" begin
        error("Outside of tests")
    end

    @testset "Different failures" begin
        @test_throws DimensionMismatch throw(ArgumentError("1"))
        @test_throws DimensionMismatch true
    end

    @testset "using function from a module" begin
        @test nthreads()>0
    end

end
