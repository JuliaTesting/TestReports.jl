
mutable struct ReportingTestSet <: AbstractTestSet
    description::AbstractString
    results::Vector
end


ReportingTestSet(desc) = ReportingTestSet(desc, [])

record(ts::ReportingTestSet, t) = (push!(ts.results, t); t)

function finish(ts::ReportingTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end

    # We are the top level, lets do this
    flatten_results!(ts)
end

#############

"""
    any_problems(ts)

Checks a testset to see if there were any problems.
Note that unlike the `DefaultTestSet`, the `ReportingTestSet`
does not throw an exception on a failure.
Thus to set the exit code you should check it using `exit(any_problems(top_level_testset))`
"""
any_problems(ts::AbstractTestSet) =  any(any_problems.(ts.results))
any_problems(::Pass) = false
any_problems(::Fail) = true
any_problems(::Broken) = false
any_problems(::Error) = true

######################################
# result flattening


"""
Returns a flat structure 2 deep, of Testset->Result
"""
function flatten_results!(ts::AbstractTestSet)
    # Dig down through any singleton levels
    while(length(ts.results) == 1 && first(ts.results) isa AbstractTestSet)
        ts.description*= "/"*first(ts.results).description
        ts.results = first(ts.results).results
    end

    # Flatten it
    ts.results = vcat(_flatten_results!.(ts.results, Val{:top}())...)
    ts
end

function _flatten_results!(ts::AbstractTestSet, ::Val) :: Vector{<:AbstractTestSet}
    original_results = ts.results
    ts.results = Result[]
    rets = AbstractTestSet[ts]
    function inner!(rs::Result)
        push!(ts.results, rs)
    end
    function inner!(childts::AbstractTestSet)
        # make it a sibling
        childts.description = ts.description * "/" * childts.description
        push!(rets, childts)
    end

    for res in original_results
        childs = _flatten_results!(res, Val{:child}())
        for child in childs
            inner!(child)
        end
    end
    rets
end

"A result without a parent testset"
_flatten_results!(rs::Result, ::Val{:top})::Vector{AbstractTestSet} = [ReportingTestSet("", [rs])]

"A result with a parent testset"
_flatten_results!(rs::Result, ::Val{:child}) = [rs]

"""
    display_reporting_testset(ts::ReportingTestSet)

Displays the test output in the same format as Pkg.test() by using a
`DefaultTestSet`.
"""
function display_reporting_testset(ts::ReportingTestSet)
    # Create top level default testset to hold all results
    ts_default = DefaultTestSet("")
    add_to_ts_default!.(Ref(ts_default), ts.results)
    try
        # Finish each of the results of the top level testset, to mimick the
        # output from Pkg.test()
        finish.(ts_default.results)
    catch
        # Don't want to error here if a test fails or errors. This is handled elswhere.
        TestSetException
    end
    return nothing
end

"""
    add_to_ts_default!(ts_default::DefaultTestSet, result::Result)
    add_to_ts_default!(ts_default::DefaultTestSet, ts::ReportingTestSet)

Populate `ts_default` with the supplied variable. If the variable is a `Result`
then it is recorded. If it is a `ReportingTestSet` then a new `DefaultTestSet`
with matching description is created, populated by recursively calling this
function and then added to the results of `ts_default`.
"""
add_to_ts_default!(ts_default::DefaultTestSet, result::Result) = record(ts_default, result)
function add_to_ts_default!(ts_default::DefaultTestSet, ts::ReportingTestSet)
    sub_ts = DefaultTestSet(ts.description)
    add_to_ts_default!.(Ref(sub_ts), ts.results)
    push!(ts_default.results, sub_ts)
end
