using FailedNestedTest, Test

@testset "FailedNestedTest" begin
    @test true

    @testset "nested" begin
        @test false
    end
end
