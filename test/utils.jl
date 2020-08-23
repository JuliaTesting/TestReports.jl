using Pkg, Test, LibGit2

# Strip the filenames from the string, so that the reference strings work on different computers
strip_filepaths(str) = replace(str, r" at .*\d+$"m => "")

# Replace direction of windows slashes so reference strings work on windows
replace_windows_filepaths(str) = replace(str, ".\\" => "./")

# Replace Int32s so reference strings work on x86 platforms
replace_Int32s(str) = replace(str, "Int32" => "Int64")

# remove stacktraces so reference strings work for different Julia versions
remove_stacktraces(str) = replace(str, r"(Stacktrace:)[^<]*" => "")

const clean_report = replace_Int32s ∘ replace_windows_filepaths ∘ strip_filepaths ∘ remove_stacktraces

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
function temp_pkg_dir(fn::Function;rm=true)
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
        copy_test_package(tmp, pkg)
        Pkg.activate(joinpath(tmp, pkg))
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
        copy_test_package(tmp, pkg)
        Pkg.activate(joinpath(tmp, pkg))
        @test_throws TestReports.PkgTestError TestReports.test(pkg)
    end
end
