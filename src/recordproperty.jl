import Test: get_testset

"""
    recordproperty(name::String, value)

Adds a property to a testset with `name` and `value` that will in turn be added
to the `<properties>` node of the corresponding testsuite in the JUnit XML.

Multiple properties can be added to one testset, but if the same property is set on
both parent and child testsets, the value in the child testset takes precedence over
that in the parent.

The suggested use of this function is to place it inside a testset with unspecified type
(see Examples). This will ensure that `Pkg.test` is unnaffected, but that the properties
are added to the report when `TestReports.test` is used. This is because properties are
only added when the `Testset` type has a `TestReports.properties` method defined, as does
the `ReportingTestSet` used by `TestReports`. `TestReports.properties` can be extended
for custom `TestSet`s.

If a child testset has this method defined but its parent doesn't, the property should
be in the report when `TestReport.test` is used, assuming that the parent testset
type doesn't do anything to affect the reporting behaviour. However this is not tested
functionality.

`value` must be serializable by EzML, which gives quite a lot of freedom.

# Examples
```julia
using TestReports

# Default testset used, so function will not affect Pkg.test but will be used when
# generating JUnit XML.
@testset "MyTestSet" begin
    recordproperty("ID", 42)
    recordproperty("File", @__FILE__)
    recordproperty("Bool", true)
    @test 1==1
    @test 2==2
end
```

See also: [`properties`](@ref)
"""
function recordproperty(name::String, val)
    properties_dict = properties(get_testset())
    if !isnothing(properties_dict)
        !isa(properties_dict, AbstractDict) && throw(PkgTestError("TestReports.properties method for custom testset must return a dictionary."))
        if haskey(properties_dict, name)
            throw(PkgTestError("Property $name already set and can't be set again in the same testset"))
        else
            get_testset().properties["$name"] = val
        end
    end
    return
end