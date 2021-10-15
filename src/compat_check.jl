
"""
    compatible(current::VersionNumber, desired::VersionNumber)
    compatible(current::VersionNumber, desired::String)
    compatible(current::VersionNumber, desired::Pkg.Types.VersionSpec)

Check whether `current` version is compatible with `desired`.
"""
compatible(current::VersionNumber, desired::VersionNumber) = compatible(current, string(desired))
compatible(current::VersionNumber, desired::String) = compatible(current, Pkg.Types.semver_spec(desired))
compatible(current::VersionNumber, desired::Pkg.Types.VersionSpec) = current in desired

"""
    check_project(project::Nothing, args...)
    check_project(project, pkg, loc)

Error if `project` has a version of TestReports which is incompatible with
this version of TestReports.
"""
check_project(project::Nothing, args...) = nothing
function check_project(project, pkg, loc)
    if hascompat(project) && haskey(getcompat(project), "TestReports")
        project_testreports_compat = getcompat(project)["TestReports"]
        !compatible(TESTREPORTS_VERSION, project_testreports_compat) && throw(PkgTestError(project_err_str(pkg, project_testreports_compat, loc)))
    end
end

"""
    check_project(project, pkg, loc, deps::Vector)
    check_project(project, pkg, loc, dep)

Error if `project` has shares a dependency with TestReports and the versions
are incompatible between `project` and TestReports.
"""
check_project(project, pkg, loc, deps::Vector) = foreach((dep)->check_project(project, pkg, loc, dep), deps)
function check_project(project, pkg, loc, dep)
    if hascompat(project) && haskey(getcompat(project), getname(dep))
        pkg_compat = getcompat(project)[getname(dep)]
        !compatible(getversion(dep), pkg_compat) && throw(PkgTestError(project_err_str(pkg, pkg_compat, getname(dep), loc, getversion(dep))))
    end
end

# Functions that let us use a Dict (< v"1.0.5") or Pkg.Types.Project/Pkg.Types.Manifest (>= v"1.1.0)
for value in ("compat", "name", "version", "deps")
    fget = Symbol("get", value)
    fhas = Symbol("has", value)
    @eval $fget(obj::Dict) = obj[$value]
    @eval $fhas(obj::Dict) = haskey(obj, $value)
    @eval $fget(obj) = getproperty(obj, Symbol($value))
    @eval $fhas(obj) = true
end

getuuid(dict::Dict) = dict["uuid"]
getuuid(pkgentry) = pkgentry.other["uuid"]

"""
    check_manifest(manifest, pkg, loc)

Error if `manifest` has a version of TestReports which is incompatible with
this version of TestReports.
"""
function check_manifest(manifest, pkg, loc)
    if hasdeps(manifest) && haskey(getdeps(manifest), TESTREPORTS_UUID)
        pkg_testreports_ver = manifest.deps[TESTREPORTS_UUID].version
        !compatible(TESTREPORTS_VERSION, pkg_testreports_ver) && throw(PkgTestError(manifest_err_str(pkg, pkg_testreports_ver, loc)))
    end
end

"""
    check_manifest(manifest, pkg, deps_to_check)

Error if `manifest` shares a dependency with TestReports and the versions
are incompatible between `manifest` and TestReports.
"""
function check_manifest(manifest, pkg, loc, dep_to_check)
    dep_uuid = Base.UUID(getuuid(dep_to_check))
    if hasdeps(manifest) && haskey(getdeps(manifest), dep_uuid)
        pkg_dep_ver = getversion(getdeps(manifest)[dep_uuid])
        !compatible(getversion(dep_to_check), pkg_dep_ver) && throw(PkgTestError(manifest_err_str(pkg, pkg_dep_ver, loc, getversion(dep_to_check))))
    end
end

"""
    check_env(env::Pkg.Types.EnvCache, pkg, loc, deps_to_check) 

Error if `env` project or manifest contains either a version of TestReports or a version
of a TestReports dependency that is incompatible with that of this version of TestReports.
"""
function check_env(env::Pkg.Types.EnvCache, pkg, loc, deps_to_check) 
    # Check TestReports
    check_project(env.project, pkg, loc)
    check_manifest(env.manifest, pkg, loc)
    # Check deps
    for dep in deps_to_check
        check_project(env.project, pkg, loc, dep)
        check_manifest(env.manifest, pkg, loc, dep)
    end
end

"""
    get_dep_entries()

Get all dependencies of TestReports that need to be checked for compatibility
with the package being tested. A dependency needs to be checked if it is listed
in both deps and compat section of TestReports Project.toml, as it is therefore
not a stdlib or Julia.
"""
function get_dep_entries end

@static if VERSION >= v"1.1"
    function get_dep_entries()
        # Get names
        testreport_proj = Pkg.Types.EnvCache(joinpath(dirname(@__DIR__), "Project.toml")).project
        dep_names_to_check = intersect(keys(testreport_proj.deps), keys(testreport_proj.compat)) # Ignores julia and stdlibs

        # Get PackageEntries from activte Manifest.toml or build from TestReports Project.toml
        deps_to_check = Pkg.Types.PackageEntry[]
        active_env = Pkg.Types.EnvCache(Base.active_project())
        for dep in dep_names_to_check
            if haskey(active_env.manifest.deps, testreport_proj.deps[dep])
                push!(deps_to_check, active_env.manifest.deps[testreport_proj.deps[dep]])
            else
                pkg_entry = Pkg.Types.PackageEntry(
                    name=dep,
                    other=Dict("uuid" => testreport_proj.deps[dep]),
                    version=VersionNumber(testreport_proj.compat[dep])
                )
                push!(deps_to_check, pkg_entry)
            end
        end
        return deps_to_check
    end
else
    function get_dep_entries()
        # Get names
        testreport_proj = Pkg.Types.EnvCache(joinpath(dirname(@__DIR__), "Project.toml")).project
        dep_names_to_check = intersect(keys(getdeps(testreport_proj)), keys(getcompat(testreport_proj))) # Ignores julia and stdlibs

        # Get PackageEntries from activte Manifest.toml or build from TestReports Project.toml
        deps_to_check = Dict[]
        active_env = Pkg.Types.EnvCache(Base.active_project())
        for dep in dep_names_to_check
            if haskey(active_env.manifest, dep)
                dep_to_check = active_env.manifest[dep][1] # why is this a vector?
                dep_to_check["name"] = dep
                push!(deps_to_check, dep_to_check) 
            else
                pkg_entry = Dict(
                    "name" => dep,
                    "uuid" => testreport_proj["deps"][dep],
                    "version" => VersionNumber(testreport_proj["compat"][dep])
                )
                push!(deps_to_check, pkg_entry)
            end
        end
        return deps_to_check
    end
end

"""
    check_testreports_compatability(ctx, pkgspec, testfilepath)

Check whether `pkgspec` and its test environment is compatible with
TestReport and its dependencies.
"""
function check_testreports_compatability(ctx, pkgspec, testfilepath)
    deps_to_check = get_dep_entries()

    # Check for TestReports and deps in package Project.toml (including extras)
    pkg_env = Pkg.Types.EnvCache(joinpath(pkgspec.path, "Project.toml"))
    check_env(pkg_env, pkgspec.name, "package", deps_to_check)

    if has_test_project_file(testfilepath)
        # TestReports and deps in test/Project.toml
        test_env = Pkg.Types.EnvCache(test_project_filepath(testfilepath))
        check_env(test_env, pkgspec.name, "test", deps_to_check)
    end
    return
end

# Utilities to make error string

function project_err_str(pkg, tr_ver, loc)
    return "$(pkg) has version $tr_ver of TestReports in its $loc compat section
        which is not compatible with TestReports version being used ($TESTREPORTS_VERSION).
        Either update compat field or use TestReports@$(tr_ver) for report generation"
end

function project_err_str(pkg, pkg_ver, dep, loc, tr_ver) 
    return """$(pkg) has version $pkg_ver of $dep in its $loc compat section
        which is not compatible with the version being used by TestReports ($tr_ver)"""
end

function manifest_err_str(pkg, pkg_ver, loc)
    return """$(pkg) has version $pkg_ver of TestReports in its $loc manifest
        which is not compatible with TestReports version being used ($TESTREPORTS_VERSION)
        Either use TestReports@$(pkg_ver) for report generation or update manifest"""
end

function manifest_err_str(pkg, pkg_ver, loc, tr_ver)
    return """$pkg has version $pkg_ver of TestReports in its $loc manifest
        which is not compatible with the version being used by TestReports ($tr_ver)
        Update the compat entry of $pkg."""
end