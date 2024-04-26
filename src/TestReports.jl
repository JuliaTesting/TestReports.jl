module TestReports

using Dates
using EzXML
using Pkg
using Printf
using Test

using Pkg: PackageSpec
using Pkg.Types: Context, ensure_resolved, is_project_uuid
using Pkg.Operations: gen_target_project, manifest_info, manifest_resolve!,
    project_deps_resolve!, project_rel_path, project_resolve!, sandbox, source_path

using Test: AbstractTestSet, DefaultTestSet, Result, Pass, Fail, Error, Broken,
    get_testset, get_testset_depth, scrub_backtrace

import Test: finish, record

# Version specific imports
@static if VERSION < v"1.7.0"
    using Pkg.Operations: update_package_test!
end

export ReportingTestSet, any_problems, report, recordproperty

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

include("./testsets.jl")
include("to_xml.jl")
include("compat_check.jl")
include("runner.jl")
include("recordproperty.jl")

end # module
