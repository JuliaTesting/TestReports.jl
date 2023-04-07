"""
    @V1_8 expr

Expression is removed if Julia version is less than v1.8.
"""
macro V1_8(expr)
    return :(
        @static if VERSION >= v"1.8"
            $(esc(expr))
        end
    )
end