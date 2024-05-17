module TestReports

using Dates
using EzXML
using Pkg
using Printf
using Test

using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid
using Pkg.Operations: manifest_info, manifest_resolve!, project_deps_resolve!,
    project_rel_path, project_resolve!

using Test: AbstractTestSet, DefaultTestSet, Result, Pass, Fail, Error, Broken,
    get_testset, get_testset_depth, scrub_backtrace

import Test: finish, record

# Version specific imports
@static if VERSION >= v"1.4.0"
    using Pkg.Operations: gen_target_project
else
    using Pkg.Operations: with_dependencies_loadable_at_toplevel
end
@static if VERSION >= v"1.2.0"
    using Pkg.Operations: sandbox, source_path
    @static if VERSION < v"1.7.0"
        using Pkg.Operations: update_package_test!
    end
else
    using Pkg.Operations: find_installed
    using Pkg.Types: SHA1
end

export ReportingTestSet, any_problems, report, record_test_property, record_testset_property

const TESTREPORTS_VERSION = let # Copied from Documenter.jl
    project = joinpath(dirname(dirname(pathof(TestReports))), "Project.toml")
    toml = Pkg.TOML.parsefile(project)
    VersionNumber(toml["version"])
end
const TESTREPORTS_UUID = let
    project = joinpath(dirname(dirname(pathof(TestReports))), "Project.toml")
    toml = Pkg.TOML.parsefile(project)
    Base.UUID(toml["uuid"])
end

include("v1_compat.jl")
include("./testsets.jl")
include("to_xml.jl")
include("compat_check.jl")
include("runner.jl")
include("properties.jl")

end # module
