
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
check_project(project::Pkg.Types.Project, pkg, loc)

Error if `project` has a version of TestReports which is incompatible with
this version of TestReports.
"""
check_project(project::Nothing, args...) = nothing
function check_project(project::Pkg.Types.Project, pkg, loc)
    if haskey(project.compat, "TestReports")
        project_testreports_compat = project.compat["TestReports"]
        !compatible(TESTREPORTS_VERSION, project_testreports_compat) && throw(PkgTestError(project_err_str(pkg, project_testreports_compat, loc)))
    end
end

"""
    check_project(project::Pkg.Types.Project, pkg, loc, deps::Vector)
    check_project(project::Pkg.Types.Project, pkg, loc, dep)

Error if `project` has shares a dependency with TestReports and the versions
are incompatible between `project` and TestReports.
"""
check_project(project::Pkg.Types.Project, pkg, loc, deps::Vector) = foreach((dep)->check_project(project, pkg, loc, dep), deps)
function check_project(project::Pkg.Types.Project, pkg, loc, dep)
    if haskey(project.compat, dep.name)
        pkg_compat = project.compat[dep.name]
        !compatible(dep.version, pkg_compat) && throw(PkgTestError(project_err_str(pkg, pkg_compat, dep.name, loc, dep.version)))
    end
end

"""
    check_manifest(manifest::Pkg.Types.Manifest, pkg, loc)

Error if `manifest` has a version of TestReports which is incompatible with
this version of TestReports.
"""
function check_manifest(manifest::Pkg.Types.Manifest, pkg, loc)
    if haskey(manifest.deps, TESTREPORTS_UUID)
        pkg_testreports_ver = manifest.deps[TESTREPORTS_UUID].version
        !compatible(TESTREPORTS_VERSION, pkg_testreports_ver) && throw(PkgTestError(manifest_err_str(pkg, pkg_testreports_ver, loc)))
    end
end

"""
    check_manifest(manifest::Pkg.Types.Manifest, pkg, deps_to_check)

Error if `manifest` shares a dependency with TestReports and the versions
are incompatible between `manifest` and TestReports.
"""
function check_manifest(manifest::Pkg.Types.Manifest, pkg, loc, dep_to_check)
    dep_uuid = Base.UUID(dep_to_check.other["uuid"])
    if haskey(manifest.deps, dep_uuid)
        pkg_dep_ver = manifest.deps[dep_uuid].version
        !compatible(dep_to_check.version, pkg_dep_ver) && throw(PkgTestError(manifest_err_str(pkg, pkg_dep_ver, loc, dep_to_check.version)))
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

"""
    check_testreports_compatability(ctx, pkgspec, testfilepath)

Check whether `pkgspec` and its test environment is compatible with
TestReport and its dependencies.
"""
function check_testreports_compatability(ctx, pkgspec, testfilepath)
    deps_to_check = get_dep_entries()

    # Check for TestReports in package Project.toml
    pkg_env = Pkg.Types.EnvCache(joinpath(pkgspec.path, "Project.toml"))
    check_env(pkg_env, pkgspec.name, "package", deps_to_check)

    # Check for TestReports and its dependencies in test dependencies of package being tested
    if has_test_project_file(testfilepath)
        # TestReports in test/Project.toml
        test_env = Pkg.Types.EnvCache(test_project_filepath(testfilepath))
        check_env(test_env, pkgspec.name, "test", deps_to_check)
    else
        # TestReports in extras and compat
        test_project = Pkg.Operations.gen_target_project(ctx, pkgspec, pkgspec.path, "test")
        check_project(test_project, pkgspec.name, "package", deps_to_check)
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