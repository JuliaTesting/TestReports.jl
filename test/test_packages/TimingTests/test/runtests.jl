using Test

# Top level test 1
sleep(1.0)
@test true

@testset "5 seconds" begin
    sleep(5)
    @test true
end

@testset "1 second" begin
    sleep(1)
    @test true
end

@testset "0.2 seconds" begin
    sleep(0.2)
    @test true
end

@testset "6 seconds combined" begin
    @testset "5 seconds (2)" begin
        sleep(5)
        @test true
    end

    @testset "1 second (2)" begin
        sleep(1)
        @test true
    end
    @test true
end

@testset "1 seconds for loop" for i in 1:2
    sleep(1)
    @test true
end

@testset "individual test timing" begin
    sleep(1.0)
    @test true
    sleep(2.0)
    @test true
    sleep(3.0)
    @test true
end

# Top level test 1
sleep(1.0)
@test true