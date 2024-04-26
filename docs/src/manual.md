# Manual

## Contents

```@contents
Pages = ["manual.md"]
Depth = 2
```

## Testing Packages

`TestReports.jl` provides two methods to test and generate JUnit XMLs for a package.
The suggested approach is to use `TestReports.test`, but additionaly a
[runner script](#Runner-Script) is also supplied.

`TestReports.test` can be used in the same way as `Pkg.test`. It will run the package unit tests,
and, by default, create a `testlog.xml` file in the current directory:

```julia
julia> TestReports.test("MyPackage")
```
!!! info "Do I need to change `runtests.jl`?"
    It is intended that it `runtests.jl` will not need to be changed to generate
    a report (unless [properties are being added](#Adding-Properties)).
    
    This does assume, however, that no custom `TestSet`s are being used. In the case of
    custom `TestSet`s, please see the [discussion](#Custom-TestSet-Types) below.

The typical use in a CI process would be:

```cmd
$ julia -e 'using Pkg; Pkg.add("TestReports"); using TestReports; TestReports.test("MyPackage")'
```

It is possible for multiple packages to be tested at once (with one report generated per package),
or for the current project to be tested:

```julia
julia> TestReports.test(["MyPackage1", "MyPackage2"])  # Multiple packages
julia> TestReports.test()  # Current project
```

`TestReports.test` will display the same output as `Pkg.test`, and accepts
the same keyword arguments, namely:

- `coverage` -  enable or disable generation of coverage statistics.
- `julia_args` - options to be passed to the test process.
- `test_args` - test arguments (`ARGS`) available in the test process.

and has two additional keyword arguments to control the name and location of the report(s):

- `logfilepath` - directory in which test reports are saved.
- `logfilename` - name(s) of test report file(s).

## Customising Testfile Name and Location

When testing a single package, the testfile name defaults to `testlog.xml` and is
saved in the current working directory. The keyword arguments `logfilepath` and
`logfilename` can be used to modify the name and/or path of the testfile, for example:

```julia
julia> TestReports.test("MyPackage", logfilename="MyPackage.xml")
# File path is joinpath(pwd(), "MyPackage.xml")
julia> TestReports.test("MyPackage", logfilepath="path")
# File path is joinpath("path", "testlog.xml")
julia> TestReports.test("MyPackage", logfilename="MyPackage.xml", logfilepath="path")
# File path is joinpath("path", "MyPackage.xml")
```

When testing multiple packages, the testfiles default to being called `PackageName_testlog.xml`
for each package. The keyword arguments can again be used to customise this, for example:

```julia
julia> TestReports.test(["MyPackage1", "MyPackage2"], logfilename=["1.xml", "2.xml"])
# File paths are joinpath(pwd(), "1.xml") and joinpath(pwd(), "2.xml")
julia> TestReports.test(["MyPackage1", "MyPackage2"], logfilename=["1.xml", "2.xml"], logfilepath="path")
# File paths are joinpath("path", "1.xml") and joinpath("path", "2.xml")
```

## Associating Properties

Properties can be associated to a testsets and/or tests by using the respective `record_testset_property` and `record_test_property` functions within a testset:

```julia
using Test
using TestReports

@testset "MyTests" begin
    record_testset_property("ID", 1)
    @test 1 == 1
end
```

The `record_*_property` functions will have no affect during normal unit testing.

The associated properties will be added to the corresponding testsuite or testcase in the generated report. Multiple properties can be added, and a properties added to a parent testset will be applied
to all child testsets. Duplicate properties are allowed to be set.

The property name must always be a `String`, but the value can be anything that is serializable
by `EzXML.jl`. In practice this means that `String`s, `Number`s, `Expr`s and `Symbols` can be used,
as well as other types.

This example shows a more complete example:

```julia
using Test
using TestReports

@testset "TopLevelTests" begin
    # This will be added to all child testsets in report. May not be appropriate when using
    # `include`.
    record_testset_property("TestFile", @__FILE__)

    @testset "MiddleLevelTests" begin
        record_testset_property("Testsuite", 100)
        record_test_property("TestSubject", "Example")

        @testset "Inner" begin
            record_testset_property("Testsuite", 101)  # Associate with both testsuite 100 and 101
            @test 1 == 1
        end

        @testset "Types" begin
            record_test_property("Prop1", :Val1)
            @test 1 == 1
        end
    end
end
```

## Runner Script

Alternatively to `TestReports.test`, `bin/reporttests.jl` is a script that runs tests and
reports the results. Use it via:

```cmd
$ julia bin/reporttests.jl tests/runtests.jl
```

Replacing `tests/runtests.jl` with the path to the package test file.
This script creates a file `testlog.xml` in the current directory.

## Known Limitations

### Single Nesting

Julia `TestSet`s can be nested to an arbitary degree, but this is not allowed
by the JUnit XML schema. Therefore, nested `TestSet`s are flatted in the report.

For example, the following `runtests.jl` file:

```julia
using Test

@testset "TopLevel" begin
    @testset "Middle1" begin
        @test 1==1
        @test 2==2
    end
    @testset "Middle2" begin
        @testset "Inner1" begin
            @test 1==1
        end
    end
    @test 1==1
end
```

Will generate the following XML (when pretty printed):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="4" failures="0" errors="0">
    <testsuite name="TopLevel/Middle1" tests="2" failures="0" errors="0" time="0.156" timestamp="2022-03-30T07:55:12.173" hostname="hostname" id="0">
        <testcase name="1 == 1" id="1" classname="TopLevel/Middle1" time="0.028"/>
        <testcase name="2 == 2" id="2" classname="TopLevel/Middle1" time="0.000"/>
    </testsuite>
    <testsuite name="TopLevel/Middle2/Inner1" tests="1" failures="0" errors="0" time="0.000" timestamp="2022-03-30T07:55:12.329" hostname="hostname" id="1">
        <testcase name="1 == 1" id="1" classname="TopLevel/Middle2/Inner1" time="0.000"/>
    </testsuite>
    <testsuite name="TopLevel" tests="1" failures="0" errors="0" time="0.156" timestamp="2022-03-30T07:55:12.173" hostname="hostname" id="2">
        <testcase name="1 == 1" id="1" classname="TopLevel" time="0.000"/>
    </testsuite>
</testsuites>
```

Each test is recorded in a separate testsuite with the name showing the original nesting.

## Custom `TestSet` Types

`TestReports.jl` has not been tested significantly with custom `TestSet` types, please
raise an issue if you find any problems/have a request.

However at a minimum, for a custom `TestSet` type to work with `TestReports` it must:
- Push itself onto its parent when finishing, if it is not at the top level
- Have `description` and `results` fields as per a `DefaultTestSet`

The following information in a JUnit XML relies on the functionality of `ReportingTestSet`s
but can be added to your own custom `TestSet` as described in the table.

|Information|Description|
|---|---|
| testcase time | This is extracted from a `ReportingResult` by the `TestReports.time_taken` function. For standard `Result`s, rather than `ReportingResult`s, this function returns `Dates.Millisecond(0)`. This function can be extended for other custom `Result` types.|
| testsuite time| This is extracted from a `TestSet` by the `TestReports.time_taken` function, which can be extended for custom `TestSet`s. If not extended, the `AbstractTestSet` method will be used and the value defaults to `Dates.Millisecond(0)`. |
| testsuite timestamp| This is extracted from a `TestSet` by the `TestReports.start_time` function, which can be extended for custom `TestSet`s. If not extended, the `AbstractTestSet` method will be used and the value defaults to `Dates.now()`. |
| testsuite hostname| This is extracted from a `TestSet` by the `TestReports.hostname` function, which can be extended for custom `TestSet`s. If not extended, the `AbstractTestSet` method will be used and the value defaults to `gethostname()`. |
| testsuite properties| This is extracted from a `TestSet` by the `TestReports.properties` function, which can be extended for custom `TestSet`s. If not extended, the `AbstractTestSet` method will be used and the value defaults to `nothing`. |

For further details on extending these fuctions, see the docstrings in [TestSets](@ref).

The [source code of `TestReports`](https://github.com/JuliaTesting/TestReports.jl/blob/master/src/testsets.jl) can be used as a starting point for including this behaviour in your custom `TestSet`s.

If no `TestSet` types are specified (as per the standard `Test` approach), `TestSet` functionality will ensure that all child `TestSet`s inherit the `ReportingTestSet` type.

