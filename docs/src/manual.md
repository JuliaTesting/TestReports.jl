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
    
    This does assume, however, that `DefaultTestSet`s are being used. In the case of
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

## Adding Properties

Properties can be added to a `TestSet` using the exported function `recordproperty`
within `runtests.jl` and other `include`d scripts:

```julia
using Test
using TestReports

@testset "MyTests" begin
    recordproperty("ID", 1)
    @test 1==1
end
```

`recordproperty` will have no affect during normal unit testing.

The added properties will be added to the corresponding testsuite in the generated report.
Multiple properties can be added, and a property added to a parent `TestSet` will be applied
to all child `TestSet`s.

An error will be thrown if the same property is set twice in a `TestSet`, and a warning
displayed if both parent and child `TestSet` have the same property set (in which case
the value set in the child will take be used in the report).

The property name must always be a `String`, but the value can be anything that is serializable
by `EzXML.jl`. In practice this means that `String`s, `Number`s, `Expr`s and `Symbols` can be used,
as well as other types.

This example shows a more complete example:

```julia
using Test
using TestReports

@testset "TopLevelTests" begin
    recordproperty("TestFile" @__FILE__)  # This will be added to all child testsets in report

    @testset "MiddleLevelTests" begin
        recordproperty("Testsuite", 100)
        recordproperty("TestSubject", "Example")

        @testset "Inner" begin
            recordproperty("Testsuite", 101)  # This will overwrite parent testset value
            @test 1==1
        end

        @testset "Types" begin
            recordproperty("Prop1", :Val1)
            @test 1==1
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

### `Pass` Result Information

When a `Test` passes, the information about the test is not retained in the `Result`.
This means that it cannot be reported, and the testcase for each passing test will be:

```xml
<testcase name="pass (info lost)" id="_testcase_id_"/>
```

This will hopefully be improved in the future - [see Julia#25483](https://github.com/JuliaLang/julia/issues/25483).

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
<testsuites name="" id="_id_" tests="4" failures="0" errors="0">
    <testsuite name="TopLevel/Middle1" id="_id_" tests="2" failures="0" errors="0">
        <testcase name="pass (info lost)" id="_testcase_id_"/>
        <testcase name="pass (info lost)" id="_testcase_id_"/>
    </testsuite>
    <testsuite name="TopLevel/Middle2/Inner1" id="_id_" tests="1" failures="0" errors="0">
        <testcase name="pass (info lost)" id="_testcase_id_"/>
    </testsuite>
    <testsuite name="TopLevel" id="_id_" tests="1" failures="0" errors="0">
        <testcase name="pass (info lost)" id="_testcase_id_"/>
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

Testsuite properties cannot be added to a `TestSet` that is not a `ReportingTestSet`,
(i.e. any `TestSet` that has the type specified to be something other than a
`ReportingTestSet`, or that inherits a specified type from a parent). If no types
are specified, `TestReports.test` will ensure that all child `TestSet`s inherit
the `ReportingTestSet` type.

