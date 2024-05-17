####################
# Type Definitions #
####################
"""
    ReportingResult{T}

Wraps a `Result` of type `T` so that additional metadata can be saved.

# fields
- `result::T`: `Result` that is being wrapped.
- `time_taken::Millisecond`: the time taken (milliseconds) for this test to be run.
"""
mutable struct ReportingResult{T} <: Result
    result::T
    time_taken::Millisecond
end
Base.:(==)(r1::ReportingResult, r2::ReportingResult) = r1.result == r2.result
Base.hash(f::ReportingResult, h::UInt) = hash(f.result, h)

"""
    time_taken(result::ReportingResult)
    time_taken(result::Result)

For a `ReportingResult`, return the time taken for the test to run.
For a `Result`, return Dates.Millisecond(0).
"""
time_taken(result::ReportingResult) = result.time_taken
time_taken(result::Result) = Dates.Millisecond(0)

"""
    ispass(result)

Return `true` if `result` is a `Pass` or a `ReportingResult{Pass}`, otherwise
return `false`.
"""
ispass(::Pass) = true
ispass(result::ReportingResult{Pass}) = ispass(result.result)
ispass(result) = false

"""
    ReportingTestSet

Custom `AbstractTestSet` type designed to be used by `TestReports.jl` for
creation of JUnit XMLs.

Does not throw an error when a test fails or has an error. Upon `finish`ing,
a `ReportingTestSet` will display the default test output, and then flatten
to a structure that is suitable for report generation.

It is designed to be wrapped around a package's `runtests.jl` file and this
is assumed when both the test results are displayed and when the `TestSet` is
flatted upon `finish`. See `bin/reporttests.jl` for an example of this use.
`ReportingTestSet`s are not designed to be used directly in a package's tests,
and this is not recommended or supported.

A `ReportingTestSet` has the `description` and `results` fields as per a
`DefaultTestSet`, and has the following additional fields:

- `properties`: used to record testsuite properties to be inserted into the report.
- `start_time::DateTime`: the start date and time of the testing (local system time).
- `time_taken::Millisecond`: the time taken in milliseconds to run the `TestSet`.
- `last_record_time::DateTime`: the time when `record` was last called.
- `hostname::String`: the name of host on which the testset was executed.

See also: [`flatten_results!`](@ref), [`recordproperty`](@ref), [`report`](@ref)
"""
mutable struct ReportingTestSet <: AbstractTestSet
    description::String
    results::Vector
    properties::Vector{Pair{String, Any}}
    start_time::DateTime
    time_taken::Millisecond
    last_record_time::DateTime
    hostname::String
    verbose::Bool
    showtiming::Bool
end

ReportingTestSet(desc; verbose=false, showtiming=true) = ReportingTestSet(desc, [], [], now(), Millisecond(0), now(), gethostname(), verbose, showtiming)

function record(ts::ReportingTestSet, t::Result)
    push!(ts.results, ReportingResult(t, now()-ts.last_record_time))
    ts.last_record_time = now()
    t
end
function record(ts::ReportingTestSet, t::AbstractTestSet)
    push!(ts.results, t)
    ts.last_record_time = now()
    t
end

function finish(ts::ReportingTestSet)
    # Record time time_taken
    ts.time_taken = now() - ts.start_time

    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end

    # Display before flattening to match Pkg.test output
    display_reporting_testset(ts)

    return ts
end

#################################
# Accessing and setting methods #
#################################

"""
    properties(ts::AbstractTestSet) -> Union{Vector{Pair{String, Any}}, Nothing}

Get the properties of a `ReportingTestSet`. Can be extended for custom testsets.
Defaults to `nothing` for an `AbstractTestSet`.

See also: [`recordproperty`](@ref) and [`recordproperty!`](@ref).
"""
properties(::AbstractTestSet) = nothing
properties(ts::ReportingTestSet) = ts.properties

"""
    recordproperty!(ts::AbstractTestSet, name::AbstractString, value)

Associate a property with the testset. Can be extended for custom testsets.

See also: [`properties`](@ref).
"""
recordproperty!(ts::AbstractTestSet, name::AbstractString, value) = ts

function recordproperty!(ts::ReportingTestSet, name::AbstractString, value)
    push!(ts.properties, name => value)
    return ts
end

"""
    start_time(ts::ReportingTestSet)
    start_time(ts::AbstractTestSet)

Get the start time of a `ReportingTestSet`, returns `Dates.now()`
for an `AbstractTestSet`. Can be extended for custom `TestSet`s,
must return a `DateTime`.
"""
start_time(ts::ReportingTestSet) = ts.start_time
start_time(ts::AbstractTestSet) = Dates.now()

"""
    time_taken(ts::ReportingTestSet)
    time_taken(ts::AbstractTestSet)

Get the time taken of a `ReportingTestSet`, returns `Dates.Millisecond(0)`
for an `AbstractTestSet`. Can be extended for custom `TestSet`s, must return
a `Dates.Millisecond`.
"""
time_taken(ts::ReportingTestSet) = ts.time_taken
time_taken(ts::AbstractTestSet) = Dates.Millisecond(0)

"""
    hostname(ts::ReportingTestSet)
    hostname(ts::AbstractTestSet)

Get the hostname of a `ReportingTestSet`, returns `gethostname()`
for an `AbstractTestSet`. Can be extended for custom `TestSet`s,
must return a `string`.
"""
hostname(ts::ReportingTestSet) = ts.hostname
hostname(ts::AbstractTestSet) = gethostname()

"""
    set_time_taken!(ts::ReportingTestSet, time_taken)
    set_time_taken!(ts::AbstractTestSet, time_taken)

Sets the time taken field of a `ReportingTestSet`. This is used when flattening
`ReportingTestSet`s for report generation and an be extended for custom `TestSet`s.
"""
set_time_taken!(ts::ReportingTestSet, time_taken::Millisecond) = ts.time_taken = time_taken
set_time_taken!(ts::AbstractTestSet, time_taken::Millisecond) = nothing
VERSION >= v"1.8" && function set_time_taken!(ts::DefaultTestSet, time_taken::Millisecond) 
    ts.time_start = 0
    ts.time_end = time_taken.value / 1000
    return ts
end


"""
    set_start_time!(ts::ReportingTestSet, start_time)
    set_start_time!(ts::AbstractTestSet, start_time)

Sets the start time field of a `ReportingTestSet`. This is used when flattening
`ReportingTestSet`s for report generation and an be extended for custom `TestSet`s.
"""
set_start_time!(ts::ReportingTestSet, start_time::DateTime) = ts.start_time = start_time
set_start_time!(ts::AbstractTestSet, start_time::DateTime) = nothing

############
# Checking #
############
"""
    any_problems(ts)

Checks a testset to see if there were any problems (`Error`s or `Fail`s).
Note that unlike the `DefaultTestSet`, the `ReportingTestSet`
does not throw an exception on a failure. Thus to set the exit code from
the runner code, we check it using `exit(any_problems(top_level_testset))`.
"""
any_problems(ts::AbstractTestSet) = any(any_problems.(ts.results))
any_problems(rs::ReportingResult) = any_problems(rs.result)
any_problems(::Pass) = false
any_problems(::Fail) = true
any_problems(::Broken) = false
any_problems(::Error) = true

#####################
# Tesult flattening #
#####################

"""
    has_description(ts::AbstractTestSet) -> Bool

Determine if the testset has been provided a description.
"""
function has_description(ts::AbstractTestSet)
    !isempty(ts.description) && ts.description != "test set"
end

"""
    flatten_results!(ts::AbstractTestSet)

Returns a flat vector of `TestSet`s which only contain `Result`s. This is necessary for
writing a JUnit XML report the schema does not allow nested XML `testsuite` elements.
"""
flatten_results!(ts::AbstractTestSet) = _flatten_results!(ts, 0)

"""
    _flatten_results!(ts::AbstractTestSet)::Vector{<:AbstractTestSet}

Recursively flatten `ts` to a vector of `TestSet`s.
"""
function _flatten_results!(ts::AbstractTestSet, depth::Int)::Vector{AbstractTestSet}
    original_results = ts.results
    has_new_properties = !isempty(something(properties(ts), tuple()))
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
        if depth > 0 || has_description(ts)
            childts.description = ts.description * "/" * childts.description
        end
        push!(flattened_results, childts)
    end

    # Iterate through original_results
    for res in original_results
        childs = _flatten_results!(res, depth + 1)
        for child in childs
            inner!(child)
        end
    end

    # Skip testsets which contain no results or new properties
    if !isempty(results) || has_new_properties
        # Use same ts to preserve description
        ts.results = results
        pushfirst!(flattened_results, ts)
    end
    return flattened_results
end

"""
    _flatten_results!(rs::Result)

Return vector containing `rs` so that when iterated through,
`rs` is added to the results vector.
"""
_flatten_results!(rs::Result, depth::Int) = [rs]

"""
    update_testset_properties!(childts::AbstractTestSet, ts::AbstractTestSet)

Adds properties of `ts` to `childts`.

If the types of `ts` and/or `childts` do not a method defined for properties, this is
handled as follows:

- If method not defined for `typeof(ts)`, it has no properties to add to `childts`
  and therefore nothing happens.
- If method not defined for `typeof(childts)` and `ts` has properties, then a warning is
  shown.

See also: [`properties`](@ref).
"""
function update_testset_properties!(childts::AbstractTestSet, ts::AbstractTestSet)
    child_props = properties(childts)
    parent_props = properties(ts)

    # Children inherit the properties of their parents
    if !isnothing(parent_props) && !isempty(parent_props)
        if !isnothing(child_props)
            prepend!(child_props, parent_props)
        else
            @warn(
                "Properties of testset \"$(ts.description)\" can not be added to " *
                "child testset \"$(childts.description)\" as it does not have a " *
                "`TestReports.properties` method defined."
            )
        end
    end
    return childts
end

"""
    display_reporting_testset(ts::ReportingTestSet)

Displays the test output in the same format as `Pkg.test` by using a
`DefaultTestSet`.
"""
function display_reporting_testset(ts::ReportingTestSet)
    # Create top level default testset to hold all results
    ts_default = DefaultTestSet("")
    add_to_ts_default!.(Ref(ts_default), ts.results)
    try
        # Finish each of the results of the top level testset, to mimick the
        # output from Pkg.test()
        for r in ts_default.results
            if r isa DefaultTestSet
                # finish sets `time_end=time()` for r. Previously we have set time_start to 0 and time_end to
                # the time taken, so this is a way of ensuring the correct time is displayed
                @static if VERSION >= v"1.8"
                    r.time_start = time() - r.time_end
                end
                finish(r)
            end
        end
    catch err
        # Don't want to error here if a test fails or errors. This is handled elswhere.
        !(err isa TestSetException) && rethrow()
    end
    return nothing
end

"""
    add_to_ts_default!(ts_default::DefaultTestSet, result::Result)
    add_to_ts_default!(ts_default::DefaultTestSet, result::ReportingResult)
    add_to_ts_default!(ts_default::DefaultTestSet, ts::AbstractTestSet)
    add_to_ts_default!(ts_default::DefaultTestSet, ts::ReportingTestSet)

Populate `ts_default` with the supplied variable. If `result` is a `Result`
or an `AbstractTestSet` (but not a `ReportingTestSet`) then it is `record`ed.
If it is a `ReportingTestSet` then a new `DefaultTestSet` with matching description
is created, populated by recursively calling this function and then added to the
results of `ts_default`. If `result` is a `ReportingResult`, the `Result` contained
by the `ReportingResult` is added to `ts_default`.
"""
add_to_ts_default!(ts_default::DefaultTestSet, result::ReportingResult) = add_to_ts_default!(ts_default, result.result)
add_to_ts_default!(ts_default::DefaultTestSet, result::Result) = record(ts_default, result)
add_to_ts_default!(ts_default::DefaultTestSet, ts::AbstractTestSet) = record(ts_default, ts)
function add_to_ts_default!(ts_default::DefaultTestSet, ts::ReportingTestSet)
    if VERSION >= v"1.8.0"
        sub_ts = DefaultTestSet(ts.description, showtiming=ts.showtiming, verbose=ts.verbose)
        set_time_taken!(sub_ts, ts.time_taken)
    else
        sub_ts = DefaultTestSet(ts.description)
    end
    add_to_ts_default!.(Ref(sub_ts), ts.results)
    push!(ts_default.results, sub_ts)
end
