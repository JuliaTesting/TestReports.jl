
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
    #to_xml(ts, Val(0))
    flatten_results!(ts)
    xml_report(ts)
end

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
