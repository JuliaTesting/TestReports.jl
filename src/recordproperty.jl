"""
    recordproperty(name::AbstractString, value)

Associates a property with a testset. The `name` and `value` will be turned into a
`<property>` element within the corresponding `<testsuite>` element within the JUnit XML
report.

Multiple properties can be added to one testset and child testsets inherit the properties
defined by their parents. If a child testset records a property which is already set both
will be present in the resulting report.

The suggested use of this function is to place it inside a testset with unspecified type
(see Examples). This will ensure that `Pkg.test` is unnaffected, but that the properties
are added to the report when `TestReports.test` is used. This is because properties are
only added when the `Testset` type has a `TestReports.properties` method defined, as does
the `ReportingTestSet` used by `TestReports`. `TestReports.properties` can be extended for
custom `TestSet`s.

If a child testset has this method defined but its parent doesn't, the property should
be in the report when `TestReport.test` is used, assuming that the parent testset
type doesn't do anything to affect the reporting behavior. However this is not tested
functionality.

The `value` argument must be serializable by EzXML, which gives quite a lot of freedom.

# Examples
```julia
using TestReports

# Default testset used, so function will not affect Pkg.test but will be used when
# generating JUnit XML.
@testset "MyTestSet" begin
    recordproperty("ID", 42)
    recordproperty("File", @__FILE__)
    recordproperty("Bool", true)
    @test 1 == 1
    @test 2 == 2
end
```

See also: [`properties`](@ref) and [`recordproperty!](@ref).
"""
function recordproperty(name::AbstractString, value)
    recordproperty!(get_testset(), name, value)
    return value
end
