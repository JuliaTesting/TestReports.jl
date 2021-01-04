using Test
import Test: AbstractTestSet, record, finish, get_testset_depth, get_testset

mutable struct NoDescriptionTestSet <: AbstractTestSet
    results::Vector
end
NoDescriptionTestSet(desc) = NoDescriptionTestSet([])
record(ts::NoDescriptionTestSet, t) = (push!(ts.results, t); t)
function finish(ts::NoDescriptionTestSet)
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
@testset NoDescriptionTestSet "ts1" begin
    @test true
end

@testset NoDescriptionTestSet "ts1" begin
    @testset NoDescriptionTestSet "ts1" begin
        @test true
    end
end