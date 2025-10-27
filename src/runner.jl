"""
The path to the test runner script provided by TestReports. Similar to running
[`TestReports.test`](@ref) but allows the user to specify any test file to run and not just
`test/runtests.jl`.

## Example

```julia
run(`\$(TestReports.RUNNER_SCRIPT) mytests.jl --output=junit-report.xml`)
```
"""
const RUNNER_SCRIPT = abspath(joinpath(@__DIR__(), "..", "bin", "reporttests.jl"))

"Exit code for runner when tests fail"
const TESTS_FAILED = 3

"""
    get_deps(manifest, pkg) = get_deps!(String[], manifest, pkg)

Get list of dependencies for `pkg` found in `manifest`
"""
get_deps(manifest, pkg) = get_deps!(String[], manifest, pkg)

"""
    get_deps!(deps, manifest, pkg)

Push dependencies for `pkg` found in `manifest` into `deps`.
"""
function get_deps!(deps, manifest, pkg)
    if VERSION >= v"1.7.0"
        manifest_dict = manifest["deps"]
    else
        manifest_dict = manifest
    end
    if haskey(manifest_dict[pkg][1], "deps")
        for dep in manifest_dict[pkg][1]["deps"]
            if !(dep in deps)
                push!(deps, dep)
                get_deps!(deps, manifest, dep)
            end
        end
    end
    return unique(deps)
end

"""
    get_manifest()

Return the parsed manifest that has `TestReports` as a dependency.
"""
function get_manifest()
    # Check all environments in LOAD_PATH to see if `TestReports` is
    # in the manifest
    for path in Base.load_path()
        manifest_path = replace(path, "Project.toml"=>"Manifest.toml")
        if isfile(manifest_path)
            manifest = Pkg.TOML.parsefile(manifest_path)
            if VERSION >= v"1.7.0"
                !haskey(manifest, "deps") && continue
                haskey(manifest["deps"], "TestReports") && return manifest
            else
                haskey(manifest, "TestReports") && return manifest
            end
        end
    end

    # Should be impossible to get here, but let's error just in case.
    throw(PkgTestError("No environment has TestReports as a dependency and TestReports is not the active project."))
    return
end

"""
    make_testreports_environment(manifest)

Make a new environment in a temporary directory, using information
from the parsed `manifest` provided.
"""
function make_testreports_environment(manifest)
    all_deps = get_deps(manifest, "TestReports")
    push!(all_deps, "TestReports")
    if VERSION >= v"1.7.0"
        new_manifest = Dict{String, Any}()
        new_manifest["deps"] = Dict(pkg => manifest["deps"][pkg] for pkg in all_deps)
        new_manifest["julia_version"] = manifest["julia_version"]
        new_manifest["manifest_format"] = manifest["manifest_format"]
        new_project = Dict(
            "deps" => Dict(
                "Test" => new_manifest["deps"]["Test"][1]["uuid"],
                "TestReports" => new_manifest["deps"]["TestReports"][1]["uuid"]
            )
        )
    else
        new_manifest = Dict(pkg => manifest[pkg] for pkg in all_deps)
        new_project = Dict(
            "deps" => Dict(
                "Test" => new_manifest["Test"][1]["uuid"],
                "TestReports" => new_manifest["TestReports"][1]["uuid"]
            )
        )
    end

    if VERSION >= v"1.11.0"
        # add REPL to Pkg weakdepends (https://github.com/JuliaTesting/TestReports.jl/issues/121#issuecomment-2413243321)
        new_manifest["deps"]["Pkg"][1]["weakdeps"] = Dict{String,Any}("REPL" => "3fa0cd96-eef1-5676-8a61-b3b8758bbffb")
    end

    testreportsenv = mktempdir()
    open(joinpath(testreportsenv, "Project.toml"), "w") do io
        Pkg.TOML.print(io, new_project)
    end
    open(joinpath(testreportsenv, "Manifest.toml"), "w") do io
        Pkg.TOML.print(io, new_manifest, sorted=true)
    end
    return testreportsenv
end

"""
    get_testreports_environment()

Returns new environment to be pushed to `LOAD_PATH` to ensure `TestReports`,
`Test` and their dependencies are available for report generation.
"""
function get_testreports_environment()
    manifest = get_manifest()    
    return make_testreports_environment(manifest)
end

"""
    gen_runner_code(testfilename, logfilename, test_args)

Returns runner code that will run the tests and generate the report in a new
Julia instance.
"""
function gen_runner_code(testfilename, logfilename, test_args)
    if Base.active_project() == joinpath(dirname(@__DIR__), "Project.toml")
        # TestReports is the active project, so push first so correct version is used
        testreportsenv = dirname(@__DIR__)
    else
        # TestReports is a dependency of one of the environments, find and build temporary environment
        testreportsenv = get_testreports_environment()
    end
    load_path_text = "pushfirst!(Base.LOAD_PATH, $(repr(testreportsenv)))"

    runner_code = """
        $(Base.load_path_setup_code(false))

        $load_path_text

        using Test
        using TestReports
        using TestReports.EzXML: prettyprint

        append!(empty!(ARGS), $(repr(test_args.exec)))

        ts = @testset ReportingTestSet "" begin
            include($(repr(testfilename)))
        end

        # Flatten before calling `report` to avoid a `deepcopy`.
        flattened_testsets = TestReports.flatten_results!(ts)
        open($(repr(logfilename)), "w") do io
            prettyprint(io, report(flattened_testsets))
        end
        any_problems(flattened_testsets) && exit(TestReports.TESTS_FAILED)
        """
    return runner_code
end

"""
    gen_command(runner_code, julia_args, coverage)

Returns `Cmd` which will run the runner code in a new Julia instance.

See also: [`gen_runner_code`](@ref)
"""
function gen_command(runner_code, julia_args, coverage)
    @static if VERSION >= v"1.5.0"
        threads_cmd = `--threads=$(Threads.nthreads())`
    else
        threads_cmd = ``
    end

    cmd = ```
        $(Base.julia_cmd())
        --code-coverage=$(coverage ? "user" : "none")
        --color=$(Base.have_color === nothing ? "auto" : Base.have_color ? "yes" : "no")
        --compiled-modules=$(Bool(Base.JLOptions().use_compiled_modules) ? "yes" : "no")
        --check-bounds=yes
        --depwarn=$(Base.JLOptions().depwarn == 2 ? "error" : "yes")
        --inline=$(Bool(Base.JLOptions().can_inline) ? "yes" : "no")
        --startup-file=$(Base.JLOptions().startupfile == 1 ? "yes" : "no")
        --track-allocation=$(("none", "user", "all")[Base.JLOptions().malloc_log + 1])
        $threads_cmd
        $(julia_args)
        --eval $(runner_code)
        ```
    return cmd
end

test_project_filepath(testfilepath) = joinpath(dirname(testfilepath), "Project.toml")
has_test_project_file(testfilepath) = isfile(test_project_filepath(testfilepath))

"""
    checkexitcode!(errs, proc, pkg, logfilename)

Checks `proc.exitcode` and acts as follows:

 - If 0, displays tests passed info message
 - If equal to `TESTS_FAILED` const, warning is displayed and `pkg` added to `errs`
 - If anything else, throws a `PkgTestError`
"""
function checkexitcode!(errs, proc, pkg, logfilename)
    if proc.exitcode == 0
        @info "$pkg tests passed. Results saved to $logfilename."
    elseif proc.exitcode == TESTS_FAILED
        @warn "ERROR: Test(s) failed or had an error in $pkg"
        push!(errs, pkg)
    else
        throw(PkgTestError("TestReports failed to generate the report.\nSee error log above."))
    end
end

"""
    runtests!(errs::Vector, pkg, cmd, logfilename)

Runs `cmd` which will run the tests of `pkg`. The exit code of the process
is then checked.
"""
function runtests!(errs::Vector, pkg, cmd, logfilename)
    @info "Testing $pkg"
    proc = open(cmd, Base.stdout; write=true)
    wait(proc)
    checkexitcode!(errs, proc, pkg, logfilename)
end

"""
    test!(pkg::AbstractString,
          errs::Vector{AbstractString},
          nopkgs::Vector{AbstractString},
          notests::Vector{AbstractString},
          logfilename::AbstractString;
          coverage::Bool=false,
          allow_reresolve::Bool=true,
          julia_args::Union{Cmd, AbstractVector{<:AbstractString}}=``,
          test_args::Union{Cmd, AbstractVector{<:AbstractString}}=``)

Tests `pkg` and save report to `logfilename`. Tests are run in the same way
as `Pkg.test`.

If tests error `pkg` is added to `nopkgs`. If `pkg` has no testfile it is added to
`notests`. If `pkg` is not installed it is added to `nopkgs`.
"""
function test!(pkg::AbstractString,
               errs::Vector{AbstractString},
               nopkgs::Vector{AbstractString},
               notests::Vector{AbstractString},
               logfilename::AbstractString;
               coverage::Bool=false,
               allow_reresolve::Union{Bool,Nothing}=nothing,
               julia_args::Union{Cmd, AbstractVector{<:AbstractString}}=``,
               test_args::Union{Cmd, AbstractVector{<:AbstractString}}=``)

    # allow_reresolve is only supported in v1.9+, so we need to bail out if it's set to any
    # non-default value on an earlier version.
    if allow_reresolve !== nothing
        VERSION < v"1.9" && throw(ArgumentError("allow_reresolve requires at least Julia 1.9"))
        testenv_kwargs = (; allow_reresolve)
    else
        testenv_kwargs = (;)
    end

    # Copied from Pkg.test approach
    julia_args = Cmd(julia_args)
    test_args = Cmd(test_args)
    ctx, pkgspec = try
        TestEnv.ctx_and_pkgspec(pkg)  # TODO: Don't use TestEnv internals
    catch err
        if err isa TestEnv.TestEnvError
            push!(nopkgs, pkg)
            return
        else
            rethrow()
        end
    end
    testfilepath = joinpath(TestEnv.get_test_dir(ctx, pkgspec), "runtests.jl")
    check_testreports_compatability(ctx, pkgspec, testfilepath)

    if !isfile(testfilepath)
        push!(notests, pkg)
    else
        runner_code = gen_runner_code(testfilepath, logfilename, test_args)
        cmd = gen_command(runner_code, julia_args, coverage)
        TestEnv.activate(pkg; testenv_kwargs...) do
            runtests!(errs, pkg, cmd, logfilename)
        end
    end
end

"""
    TestReports.test(; kwargs...)
    TestReports.test(pkg::Union{AbstractString, Vector{AbstractString}; kwargs...)

# Keyword arguments:
  - `coverage::Bool=false`: enable or disable generation of coverage statistics.
  - `julia_args::Union{Cmd, Vector{String}}`: options to be passed to the test process.
  - `test_args::Union{Cmd, Vector{String}}`: test arguments (`ARGS`) available in the test process.
  - `logfilepath::AbstractString=pwd()`: file path where test reports are saved.
  - `logfilename::Union{AbstractString, Vector{AbstractString}}`: name(s) of test report file(s).

Generates a JUnit XML for the tests of package `pkg`, or for the current project
(which thus needs to be a package) if no positional argument is given to
`TestReports.test`. The test report is saved in the current working directory and
called `testlog.xml` if both `logfilepath` and `logfilename` are not supplied.
If `pkg` is of type `Vector{String}`, the report filenames are prepended with the
package name, for example `Example_testlog.xml`.

If `logfilename` is supplied, it must match the type (and length, if a vector) of `pkg`.

The tests are run in the same way as `Pkg.test`.
"""
function test(; kwargs...)
    ctx = Pkg.Types.Context()
    # This error mirrors the message generated by Pkg.test in similar situations
    ctx.env.pkg === nothing && throw(PkgTestError("trying to test an unnamed project"))
    test(ctx.env.pkg.name; kwargs...)
end
test(pkg::AbstractString; logfilename::AbstractString="testlog.xml", kwargs...) = test([pkg]; logfilename=[logfilename], kwargs...)
function test(pkgs::Vector{<:AbstractString}; 
              logfilename::Vector{<:AbstractString}=[pkg * "_testlog.xml" for pkg in pkgs], 
              logfilepath::AbstractString=pwd(), 
              kwargs...)
              
    # Argument check
    err_str = "The number of file names supplied must equal the number of packages being tested"
    length(pkgs) != length(logfilename) && throw(ArgumentError(err_str))

    # Make logfilepath directory if it doesn't exist
    !isdir(logfilepath) && mkdir(logfilepath)

    errs = AbstractString[]
    nopkgs = AbstractString[]
    notests = AbstractString[]
    for (pkg, filename) in zip(pkgs, logfilename)
        test!(pkg, errs, nopkgs, notests, joinpath(logfilepath, filename); kwargs...)
    end
    if !all(isempty, (errs, nopkgs, notests))
        messages = AbstractString[]
        if !isempty(errs)
            push!(messages, "$(join(errs,", "," and ")) had test errors")
        end
        if !isempty(nopkgs)
            msg = length(nopkgs) > 1 ? " are not installed packages" :
                                       " is not an installed package"
            push!(messages, string(join(nopkgs,", ", " and "), msg))
        end
        if !isempty(notests)
            push!(messages, "$(join(notests,", "," and ")) did not provide a test/runtests.jl file")
        end
        throw(PkgTestError(join(messages, " and ")))
    end
end

struct PkgTestError <: Exception
    msg::AbstractString
end

function Base.showerror(io::IO, ex::PkgTestError, bt; backtrace=true)
    printstyled(io, ex.msg, color=Base.error_color())
end
