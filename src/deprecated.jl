using Base: depwarn

export recordproperty

function recordproperty(name::String, val)
    depwarn("`recordproperty` is deprecated, use `record_testset_property` instead.", :recordproperty)
    record_testset_property(name, val)
    return nothing
end

function properties(ts::AbstractTestSet)
    depwarn("`$properties` is deprecated, use `$testset_properties` instead.", :properties)
    p = testset_properties(ts)
    return isnothing(p) ? nothing : Dict(p)
end
