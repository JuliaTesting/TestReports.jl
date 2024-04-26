"""
    record_testset_property(name::AbstractString, value)

Associates a property with a testset. The `name` and `value` will be turned into a
`<property>` element within the corresponding `<testsuite>` element within the JUnit XML
report.

Multiple properties can be added to one testset and child testsets inherit the properties
defined by their parents. If a child testset records a property which is already set both
will be present in the resulting report.

The suggested use of this function is to place it inside a testset with unspecified type
(see Examples). This will ensure that `Pkg.test` is unnaffected, but that the properties
are added to the report when `TestReports.test` is used. This is because properties are
only added when the `Testset` type has a `TestReports.testset_properties` method defined, as
does the `ReportingTestSet` used by `TestReports`. `TestReports.testset_properties` can be
extended for custom `TestSet`s.

If a child testset has this method defined but its parent doesn't, the property should
be in the report when `TestReport.test` is used, assuming that the parent testset
type doesn't do anything to affect the reporting behaviour. However this is not tested
functionality.

The `value` argument must be serializable by EzXML, which gives quite a lot of freedom.

# Examples
```julia
using TestReports

# Default testset used, so function will not affect Pkg.test but will be used when
# generating JUnit XML.
@testset "MyTestSet" begin
    record_testset_property("ID", 42)
    record_testset_property("File", @__FILE__)
    record_testset_property("Bool", true)
    @test 1 == 1
    @test 2 == 2
end
```

See also: [`testset_properties`](@ref), [`record_test_property`](@ref).
"""
function record_testset_property(name::AbstractString, value)
    record_testset_property!(get_testset(), name, value)
    return value
end

"""
    record_test_property(name::AbstractString, value)

Associates a property with the tests contained with the testset. The `name` and `value` will
be turned into a `<property>` element with the corresponding `<testcase>` element within the
JUnit XML report.

Multiple test properties can be assigned within a testset and child testsets will inherit
the test properties defined by their parents. If a child testset records a test property
with an already used name both properties will be present in the resulting report.

For more details see the documentation for [`record_testset_property`](@ref).

# Examples
```julia
using TestReports

# Default testset used, record property call is ignored by `Pkg.test` but will be used when
# generating JUnit XML.
@testset "MyTestSet" begin
    record_test_property("ID", 42)
    record_test_property("File", @__FILE__)
    record_test_property("Bool", true)
    @test 1 == 1
    @test 2 == 2
end
```

See also: [`test_properties`](@ref), [`record_testset_property`](@ref).
"""
function record_test_property(name::AbstractString, value)
    record_test_property!(get_testset(), name, value)
    return value
end
