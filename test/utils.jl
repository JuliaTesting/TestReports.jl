using Dates, Pkg, Test, LibGit2
import Test: finish, record, AbstractTestSet, get_testset_depth, get_testset, Result

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

const clean_output = strip_filepaths ∘ remove_stacktraces ∘ remove_test_output ∘ remove_timing_info ∘ remove_timestamp_info ∘ default_hostname_info

"""
`copy_test_package` copied from [`Pkg.jl/test/utils.jl`](https://github.com/JuliaLang/Pkg.jl/blob/v1.4.2/test/utils.jl#L209).
https://github.com/JuliaLang/Pkg.jl/blob/master/test/utils.jl
"""
function copy_test_package(tmpdir::String, name::String; use_pkg=true)
    target = joinpath(tmpdir, name)
    cp(joinpath(@__DIR__, "test_packages", name), target)
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

Function has been modified to be compatible with both v1.0.5 and v1.4.0, and
the DEPOT_PATH behaviour has been changed so that DEPOT_PATH is unchanged.
"""
function temp_pkg_dir(fn::Function;rm=true, add_testresports_env=true)
    testreportsenv = TestReports.get_testreports_environment()
    old_load_path = copy(LOAD_PATH)
    # old_depot_path = copy(DEPOT_PATH)
    old_home_project = Base.HOME_PROJECT[]
    old_active_project = Base.ACTIVE_PROJECT[]
    VERSION >= v"1.4.0" ?
        old_general_registry_url = Pkg.Types.DEFAULT_REGISTRIES[1].url :
        old_general_registry_url = Pkg.Types.DEFAULT_REGISTRIES["General"]
    try
        # Clone the registry only once
        generaldir = joinpath(@__DIR__, "registries", "General")
        if !isdir(generaldir)
            mkpath(generaldir)
            if VERSION >= v"1.4.0"
                LibGit2.with(Pkg.GitTools.clone(Pkg.Types.Context(),
                                                "https://github.com/JuliaRegistries/General.git",
                                                generaldir)) do repo
                end
            else
                LibGit2.with(Pkg.GitTools.clone("https://github.com/JuliaRegistries/General.git",
                                                generaldir)) do repo
                end
            end
        end
        empty!(LOAD_PATH)
        # empty!(DEPOT_PATH)
        Base.HOME_PROJECT[] = nothing
        Base.ACTIVE_PROJECT[] = nothing
        VERSION >= v"1.4.0" ?
            Pkg.Types.DEFAULT_REGISTRIES[1].url = generaldir :
            Pkg.Types.DEFAULT_REGISTRIES["General"] = generaldir
        withenv("JULIA_PROJECT" => nothing,
                "JULIA_LOAD_PATH" => nothing,
                "JULIA_PKG_DEVDIR" => nothing) do
            env_dir = mktempdir()
            # depot_dir = mktempdir()
            try
                push!(LOAD_PATH, "@", "@v#.#", "@stdlib")
                add_testresports_env && push!(LOAD_PATH, testreportsenv)
                # push!(DEPOT_PATH, depot_dir)
                fn(env_dir)
            finally
                try
                    rm && Base.rm(env_dir; force=true, recursive=true)
                    # rm && Base.rm(depot_dir; force=true, recursive=true)
                catch err
                    # Avoid raising an exception here as it will mask the original exception
                    println(Base.stderr, "Exception in finally: $(sprint(showerror, err))")
                end
            end
        end
    finally
        empty!(LOAD_PATH)
        # empty!(DEPOT_PATH)
        append!(LOAD_PATH, old_load_path)
        # append!(DEPOT_PATH, old_depot_path)
        Base.HOME_PROJECT[] = old_home_project
        Base.ACTIVE_PROJECT[] = old_active_project
        VERSION >= v"1.4.0" ?
            Pkg.Types.DEFAULT_REGISTRIES[1].url = old_general_registry_url :
            Pkg.Types.DEFAULT_REGISTRIES["General"] = old_general_registry_url
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
    test_active_package_expected_pass(pkg::String)

Helper function which activates `pkg` in an isolated temporary directory and
runs `TestReports.test(pkg)`.
"""
function test_active_package_expected_pass(pkg::String)
    temp_pkg_dir() do tmp
        path = copy_test_package(tmp, pkg)
        Pkg.activate(path)
        TestReports.test(pkg)
        test_successful_testrun(() -> TestReports.test(pkg), pkg)
    end
end

"""
    test_package_expected_pass(pkg::String)

Helper function which develops `pkg` in an isolated temporary directory and
runs `TestReports.test(pkg)`.
"""
function test_package_expected_pass(pkg::String)
    temp_pkg_dir() do tmp
        path = copy_test_package(tmp, pkg)
        Pkg.develop(Pkg.PackageSpec(path=path))
        TestReports.test(pkg)
        test_successful_testrun(() -> TestReports.test(pkg), pkg)
    end
end

"""
    test_active_package_expected_fail(pkg::String)

Helper function which activates `pkg` in an isolated temporary directory and
runs `TestReports.test(pkg)`, expecting the report writing to fail with a
`PkgTestError`.
"""
function test_active_package_expected_fail(pkg::String)
    temp_pkg_dir() do tmp
        path = copy_test_package(tmp, pkg)
        Pkg.activate(path)
        @test_throws TestReports.PkgTestError TestReports.test(pkg)
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
        path = copy_test_package(tmp, pkg)
        Pkg.develop(Pkg.PackageSpec(path=path))
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

mutable struct WrongPropsTestSet <: AbstractTestSet
    description::String
    results::Vector
    properties::String
end
WrongPropsTestSet(desc) = WrongPropsTestSet(desc, [], "")
record(ts::WrongPropsTestSet, t) = (push!(ts.results, t); t)
function finish(ts::WrongPropsTestSet)
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
TestReports.properties(ts::WrongPropsTestSet) = ts.properties