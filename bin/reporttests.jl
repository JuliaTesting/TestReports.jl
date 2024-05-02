#!/usr/bin/env julia

# Usage:
#   reporttests.jl TEST_FILENAME [LOG_FILENAME] -- [test_args...]

using TestReports

# Basic argument parsing without using an extra dependency
function parse_args(args)
    test_filename = nothing
    log_filename = nothing
    test_args = String[]

    found_double_dash = false
    for (i, arg) in enumerate(args)
        if arg == "--"
            found_double_dash = true
            continue
        end

        if isnothing(test_filename) && !found_double_dash
            test_filename = arg
        elseif isnothing(log_filename) && !found_double_dash
            log_filename = arg
        elseif found_double_dash
            push!(test_args, arg)
        else
            error("Encountered unexpected CLI positional argument $i")
        end
    end

    if isnothing(test_filename)
        error("Required argument `test_filename` not set")
    end

    return (; test_filename, log_filename, test_args)
end

if abspath(PROGRAM_FILE) == @__FILE__()
    parsed = parse_args(ARGS)
    coverage = Base.JLOptions().code_coverage != 0
    runner_code = TestReports.gen_runner_code(
        parsed.test_filename,
        something(parsed.log_filename, "testlog.xml"),
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
