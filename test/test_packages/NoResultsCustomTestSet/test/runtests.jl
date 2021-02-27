using Test
using Test: AbstractTestSet, get_testset_depth, get_testset

import Test: finish, record

mutable struct NoResultsTestSet <: AbstractTestSet
    description::String
end
record(ts::NoResultsTestSet, t) = t
function finish(ts::NoResultsTestSet)
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
@testset NoResultsTestSet "ts1" begin
    @test true
end