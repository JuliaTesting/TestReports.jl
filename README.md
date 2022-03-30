# TestReports

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliatesting.github.io/TestReports.jl/stable)
[![Build Status](https://github.com/JuliaTesting/TestReports.jl/workflows/CI/badge.svg?branch=master)](https://github.com/JuliaTesting/TestReports.jl/actions?query=workflow%3ACI+branch%3Amaster)
[![Codecov](https://codecov.io/gh/JuliaTesting/TestReports.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaTesting/TestReports.jl)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

This package produces JUnit XML test reports. It is for use with your CI tooling of choice,
for example a CI tool like GoCD consumes reports in this format and gives back HTML reports.

## Getting Started

The reporting is designed to enable you to write your unit tests in the standard Julia way,
that is using `test/runtests.jl` as the entry point to your tests and with default `TestSet`
types. In theory, it should also work with custom `TestSet` types - see the
[Manual](https://juliatesting.github.io/TestReports.jl/stable) for 
further information.

To test and generate a report for your package:

```julia
julia> TestReports.test("MyPackage")
# Unit tests run, report saved to testlog.xml in current working directory
```

To add to CI:

```cmd
$ julia -e 'using Pkg; Pkg.add("TestReports"); using TestReports; TestReports.test("MyPackage")'
```

Additionally, properties can be added to your `TestSet`s. To do this, use the `recordproperty`
function like so:

```julia
using Test
using TestReports

@testset "MyTests" begin
    recordproperty("ID", 1)
    @test 1==1
end
```

## Example of Use

Below is a screen shot of TestReports being used with [GoCD](https://github.com/gocd/gocd/),
to report an test failure in [DataDepsGenerators.jl](https://github.com/oxinabox/DataDepsGenerators.jl/).

![Screenshot of GoCD web-interface showing failing tests](docs/src/assets/FailingTests.PNG)

The corresponding `testlog.xml` file (produced with an earlier version of `TestReports`, and therefore missing some of the new features, and after pretty printing) is below.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="/UCI" id="now" tests="7" failures="1" errors="0">
  <testsuite name="" id="_id_" tests="1" failures="0" errors="0">
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
  <testsuite name="" id="_id_" tests="1" failures="0" errors="0">
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
  <testsuite name="" id="_id_" tests="1" failures="0" errors="0">
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
  <testsuite name="" id="_id_" tests="1" failures="0" errors="0">
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
  <testsuite name="" id="_id_" tests="1" failures="0" errors="0">
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
  <testsuite name="ForestFires" id="_id_" tests="2" failures="1" errors="0">
    <testcase name="contains(registration_block, &quot;A Data Mining Approach to Predict Forest Fires using Meteorological Data&quot;)" id="_testcase_id_">
      <failure message="nothing" type="test">Test Failed
  Expression: contains(registration_block, "A Data Mining Approach to Predict Forest Fires using Meteorological Data")</failure>
    </testcase>
    <testcase name="pass (info lost)" id="_testcase_id_"/>
  </testsuite>
</testsuites>
```