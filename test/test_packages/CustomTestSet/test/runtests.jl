using Test
import Test: AbstractTestSet, record, finish, get_testset_depth, get_testset

mutable struct MyTestSet <: AbstractTestSet
    description::String
    results::Vector
end
MyTestSet(desc) = MyTestSet(desc, [])
record(ts::MyTestSet, t) = (push!(ts.results, t); t)
function finish(ts::MyTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end

    return ts
end

# Top level tests captured in ReportingTestSet in TestReports
@test true

# Simple custom TestSet
@testset MyTestSet "ts1" begin
    @test true
end

# More complex custom TestSet
@testset MyTestSet "ts2" begin
    @testset MyTestSet "ts3" begin
        @test true
    end
    @test true
end

# No TestSet specified, should use ReportingTestSet in TestReports
@testset "ts4" begin
    @testset "ts5" begin
        @test true
    end
    @test true
end