@static if VERSION < v"1.1.0"
    """
        isnothing(x)

    Return `true` if `x === nothing`, and return `false` if not.
    """
    isnothing(::Any) = false
    isnothing(::Nothing) = true
end