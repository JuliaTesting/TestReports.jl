using Dates
using Pkg
using Test
using Test: AbstractTestSet, Result, get_testset, get_testset_depth 

import Test: finish, record

# Strip the filenames from the string, so that the reference strings work on different computers
strip_filepaths(str) = replace(str, r" at .*\d+$"m => "")

# remove stacktraces so reference strings work for different Julia versions
remove_stacktraces(str) = replace(str, r"(Stacktrace:)[^<]*" => "")

# remove test output - remove everything before "<?xml version"
remove_test_output(str) = replace(str, r"^[\S\s]*(?=(<\?xml version))" => "")

# Zero timing output - we want "time" there to check its being recorded
remove_timing_info(str) = replace(str, r"\stime=\\\"[0-9.-]*\\\"" => " time=\"0.0\"")

# Zero timestamp output - we want "timestamp" there to check its being recorded
remove_timestamp_info(str) = replace(str, r"\stimestamp=\\\"[0-9-T:.]*\\\"" => " timestamp=\"0\"")

# Default hostname output - we want "hostname" there to check its being recorded
default_hostname_info(str) = replace(str, r"\shostname=\\\"[\S]*\\\"" => " hostname=\"localhost\"")

pretty_format_xml(str) = sprint(prettyprint, parsexml(str))

const clean_output = pretty_format_xml ∘ strip_filepaths ∘ remove_stacktraces ∘ remove_test_output ∘ remove_timing_info ∘ remove_timestamp_info ∘ default_hostname_info

test_package_path(pkg) = joinpath(@__DIR__, "test_packages", pkg)

"""
`copy_test_package` copied from [`Pkg.jl/test/utils.jl`](https://github.com/JuliaLang/Pkg.jl/blob/v1.4.2/test/utils.jl#L209).
https://github.com/JuliaLang/Pkg.jl/blob/master/test/utils.jl
"""
function copy_test_package(tmpdir::String, name::String; use_pkg=true)
    target = joinpath(tmpdir, name)
    cp(test_package_path(name), target)
    use_pkg || return target

    # The known Pkg UUID, and whatever UUID we're currently using for testing
    known_pkg_uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
    pkg_uuid = Pkg.TOML.parsefile(joinpath(dirname(@__DIR__), "Project.toml"))["uuid"]

    # We usually want this test package to load our pkg, so update its Pkg UUID:
    test_pkg_dir = joinpath(@__DIR__, "test_packages", name)
    for f in ("Manifest.toml", "Project.toml")
        fpath = joinpath(tmpdir, name, f)
        if isfile(fpath)
            chmod(fpath, 0o777) # Ensure writable
            write(fpath, replace(read(fpath, String), known_pkg_uuid => pkg_uuid))
        end
    end
    return target
end

"""
`temp_pkg_dir` copied from Pkg.jl as cannot be imported during tests.
https://github.com/JuliaLang/Pkg.jl/blob/master/test/utils.jl

Function has been modified to be compatible with both v1.0.5 and v1.4.0,
the DEPOT_PATH behaviour has been changed so that DEPOT_PATH is unchanged,
and the current registry is used rather than a new one downloaded.
"""
function temp_pkg_dir(fn::Function;rm=true, add_testresports_env=true)
    testreportsenv = TestReports.get_testreports_environment()
    old_load_path = copy(LOAD_PATH)
    old_home_project = Base.HOME_PROJECT[]
    old_active_project = Base.ACTIVE_PROJECT[]
    try
        empty!(LOAD_PATH)
        Base.HOME_PROJECT[] = nothing
        Base.ACTIVE_PROJECT[] = nothing
        withenv("JULIA_PROJECT" => nothing,
                "JULIA_LOAD_PATH" => nothing,
                "JULIA_PKG_DEVDIR" => nothing) do
            env_dir = mktempdir()
            Base.ACTIVE_PROJECT[] = env_dir
            try
                push!(LOAD_PATH, env_dir, "@stdlib")
                add_testresports_env && push!(LOAD_PATH, testreportsenv)
                fn(env_dir)
            finally
                try
                    rm && Base.rm(env_dir; force=true, recursive=true)
                catch err
                    # Avoid raising an exception here as it will mask the original exception
                    println(Base.stderr, "Exception in finally: $(sprint(showerror, err))")
                end
            end
        end
    finally
        empty!(LOAD_PATH)
        append!(LOAD_PATH, old_load_path)
        Base.HOME_PROJECT[] = old_home_project
        Base.ACTIVE_PROJECT[] = old_active_project
    end
end

"""
Helper function to verify the runner successfully ran a test suite based on
the Info messages that were logged.
"""
function test_successful_testrun(testrun::Function, project::AbstractString)
    successful_pass_matcher = Regex("$(project) tests passed. Results saved to .+\\.\$")
    @test_logs (:info, "Testing $(project)") (:info, successful_pass_matcher) match_mode=:any testrun()
end

"""
    test_package_expected_pass(pkg::String)

Helper function which develops `pkg` in an isolated temporary directory and
runs `TestReports.test(pkg)`.
"""
function test_package_expected_pass(pkg::String)
    temp_pkg_dir() do tmp
        Pkg.develop(Pkg.PackageSpec(path=test_package_path(pkg)))
        test_successful_testrun(() -> TestReports.test(pkg), pkg)
    end
end

"""
    test_package_expected_fail(pkg::String)

Helper function which develops `pkg` in an isolated temporary directory and
runs `TestReports.test(pkg)`, expecting the report writing to fail with a
`PkgTestError`.
"""
function test_package_expected_fail(pkg::String)
    temp_pkg_dir() do tmp
        Pkg.develop(Pkg.PackageSpec(path=test_package_path(pkg)))
        @test_throws TestReports.PkgTestError TestReports.test(pkg)
    end
end

# Test TestSets
"""
    TestReportingTestSet

Mimics a `ReportingTestSet` but does not have the properties field or
`flatten` on `finish`.
"""
mutable struct TestReportingTestSet <: AbstractTestSet
    description::AbstractString
    results::Vector
    start_time::DateTime
end
TestReportingTestSet(desc) = TestReportingTestSet(desc, [], Dates.now())
function record(ts::TestReportingTestSet, t::Result)
    push!(ts.results, TestReports.ReportingResult(t, Millisecond(0)))
    t
end
function record(ts::TestReportingTestSet, t::AbstractTestSet)
    push!(ts.results, t)
    t
end
function finish(ts::TestReportingTestSet)
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end
    return ts
end

mutable struct NoDescriptionTestSet <: AbstractTestSet
    results::Vector
end
NoDescriptionTestSet(desc) = NoDescriptionTestSet([])
record(ts::NoDescriptionTestSet, t) = (push!(ts.results, t); t)
function finish(ts::NoDescriptionTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end

    return ts
end

mutable struct NoResultsTestSet <: AbstractTestSet
    description::String
end
record(ts::NoResultsTestSet, t) = t
function finish(ts::NoResultsTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end

    return ts
end
