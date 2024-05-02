#!/usr/bin/env julia

# Usage:
#   reporttests.jl TEST_FILENAME [--output=LOG_FILENAME] -- [test_args...]
#   julia reporttests.jl -- TEST_FILENAME [--output=LOG_FILENAME] -- [test_args...]

using TestReports

# Basic argument parsing without requring an extra dependency like ArgParse.jl
function parse_args(args)
    test_filename = nothing
    output_filename = nothing
    test_args = String[]

    option_key = nothing
    state = :options
    for (i, arg) in enumerate(args)
        if state === :options && option_key !== nothing
            if option_key == "--output"
                output_filename = arg
            else
                error("Unhandled option: `$option_key`")
            end
            option_key = nothing
        elseif state === :options && option_match(("--output", "-o"), arg)
            option = split(arg, '='; limit=2)
            if length(option) == 2
                output_filename = option[2]
            else
                option_key = "--output"
            end
        elseif state === :options && arg == "--"
            # Ignore the first double-dash as Julia versions before 1.9.0-DEV.604 would
            # automatically exclude it.
            # https://github.com/JuliaLang/julia/pull/45335
            i > 1 && (state = :positional_args)
        elseif test_filename === nothing
            test_filename = arg
        else
            push!(test_args, arg)
        end
    end

    if test_filename === nothing
        throw(ArgumentError("Required positional argument `test_filename` not set"))
    end

    # Use Julia 1.0 compatible named tuple syntax without Compat.jl
    return (; test_filename=test_filename, output_filename=output_filename, test_args=test_args)
end

function option_match(option_keys, arg)
    return arg in option_keys || any(o -> startswith(arg, "$o="), option_keys)
end

if abspath(PROGRAM_FILE) == @__FILE__()
    parsed = parse_args(ARGS)
    coverage = Base.JLOptions().code_coverage != 0
    runner_code = TestReports.gen_runner_code(
        parsed.test_filename,
        something(parsed.output_filename, "testlog.xml"),
        Cmd(parsed.test_args),
    )
    cmd = TestReports.gen_command(runner_code, ``, coverage)

    try
        run(cmd)
    catch e
        e isa ProcessFailedException && exit(only(e.procs).exitcode)
        rethrow()
    end
end
