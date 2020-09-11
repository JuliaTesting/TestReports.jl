
mutable struct ReportingTestSet <: AbstractTestSet
    description::String
    results::Vector
    properties::Dict{String, Any}
end

ReportingTestSet(desc) = ReportingTestSet(desc, [], Dict())

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
    flatten_results!(ts::AbstractTestSet)

Returns a flat structure 3 deep, of `TestSet` -> `TestSet` -> `Result`. This is necessary
for writing a report, as a JUnitXML does not allow one testsuite to be nested in another.
The top level `TestSet` becomes the testsuites element, and the middle level `TestSet`s
become individual testsuite elements, and the `Result`s become the testcase elements.

If `ts.results` contains any `Result`s, these are added into a new `TestSet` with the
description "Top level tests", which then replaces them in `ts.results`.
"""
function flatten_results!(ts::AbstractTestSet)
    # Add any top level Results to their own TestSet
    handle_top_level_results!(ts)

    # Flatten all results of top level testset, which should all be testsets now
    ts.results = vcat(_flatten_results!.(ts.results)...)
    return ts
end

"""
    _flatten_results!(ts::AbstractTestSet) ::Vector{<:AbstractTestSet}

Recursively flatten `ts` to a vector of `TestSet`s.
"""
function _flatten_results!(ts::AbstractTestSet) ::Vector{<:AbstractTestSet}
    original_results = ts.results
    flattened_results = AbstractTestSet[]
    # Track results that are a Result so that if there are any, they can be added
    # in their own testset to flattened_results
    results = Result[]

    # Define nested functions
    function inner!(rs::Result)
        # Add to results vector
        push!(results, rs)
    end
    function inner!(childts::AbstractTestSet)
        # Make it a sibling
        update_testset_properties!(childts, ts)
        childts.description = ts.description * "/" * childts.description
        push!(flattened_results, childts)
    end

    # Iterate through original_results
    for res in original_results
        childs = _flatten_results!(res)
        for child in childs
            inner!(child)
        end
    end

    # results will be empty if ts.results only contains testsets
    if !isempty(results)
        # Use same ts to preserve description
        ts.results = results
        push!(flattened_results, ts)
    end
    return flattened_results
end

"""
    _flatten_results!(rs::Result)

Return vector containing `rs` so that when iterated through,
`rs` is added to the results vector.
"""
_flatten_results!(rs::Result) = [rs]

"""
    update_testset_properties!(childts::AbstractTestSet, ts::AbstractTestSet)
    update_testset_properties!(childts::ReportingTestSet, ts::ReportingTestSet)

Adds properties of `ts` to `childts`. If any properties being added already exist in
`childts`, a warning is displayed and the value in `childts` is overwritten.

If `ts` and\\or `childts` is not a `ReportingTestSet`, this is handled in the
`AbstractTestSet` method.
"""
function update_testset_properties!(childts::AbstractTestSet, ts::AbstractTestSet)
    if !isa(childts, ReportingTestSet) && isa(ts, ReportingTestSet) && !isempty(ts.properties)
        @warn "Properties of testset $(ts.description) can not be added to child testset $(childts.description) as it is not a ReportingTestSet."
    end
    # No need to check if childts is ReportingTestSet and ts isn't, as if this is the case
    # ts has no properties to apply to childts.
    return childts
end
function update_testset_properties!(childts::ReportingTestSet, ts::ReportingTestSet)
    parent_keys = keys(ts.properties)
    child_keys = keys(childts.properties)
    # Loop through keys so that warnings can be issued for any duplicates
    for key in parent_keys
        if key in child_keys
            @warn "Property $key in testest $(ts.description) overwritten by child testset $(childts.description)"
        else
            childts.properties[key] = ts.properties[key]
        end
    end
    return childts
end

"""
    handle_top_level_results!(ts::AbstractTestSet)

If `ts.results` contains any `Results`, these are removed from `ts.results` and
added to a new `ReportingTestSet`, which in turn is added to `ts.results`. This
leaves `ts.results` only containing `AbstractTestSet`s.
"""
function handle_top_level_results!(ts::AbstractTestSet)
    isa_Result = isa.(ts.results, Result)
    if any(isa_Result)
        original_results = ts.results
        ts.results = AbstractTestSet[]
        ts_nested = ReportingTestSet("Top level tests")
        ts_nested.results = original_results[isa_Result]
        push!(ts.results, ts_nested)
        append!(ts.results, original_results[.!isa_Result])
    end
    return ts
end

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
    catch TestSetException
        # Don't want to error here if a test fails or errors. This is handled elswhere.
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
