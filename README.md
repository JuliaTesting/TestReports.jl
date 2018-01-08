# TestReports

[![Build Status](https://travis-ci.org/oxinabox/TestReports.jl.svg?branch=master)](https://travis-ci.org/oxinabox/TestReports.jl)

[![Coverage Status](https://coveralls.io/repos/oxinabox/TestReports.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/oxinabox/TestReports.jl?branch=master)

[![codecov.io](http://codecov.io/github/oxinabox/TestReports.jl/coverage.svg?branch=master)](http://codecov.io/github/oxinabox/TestReports.jl?branch=master)



This package produces JUnit style XML test reports.
It is for use with your tooling of choice
For example, a CI tool like GoCD consumes reports in this format and gives back HTML reports.

There are some awkwardness, as julia testsets can be nested to an arbitary degree,
where as JUnit dones not allow this.
So we flatten all the results down for the report.

There are also some limitations with the information that is provided, this is relatating to issues with `Base.Test`.
We (the JuliaLang community) are working on that.

## Example of Use
Below is a screen shot of TestReports being used with [GoCD](https://github.com/gocd/gocd/),
to report an test failure in []DataDepsGenerators.jl](https://github.com/oxinabox/DataDepsGenerators.jl/).

![Screenshot of GoCD web-interface showing failing tests](docs/imgs/FailingTests.PNG)

The corresponding `testlog.xml` file is below.
(After pretty printing)

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

## Manual

### Runner Script

`bin/reporttests.jl` is a script that runs tests and reports the results.
Use it via:

```
julia bin/reporttests.jl tests/runtests.jl
```

Replacing `/tests/runtests.jl` with the path to your testfile.
This script creates a file `testlog.xml` in the current directory.

### Testing packages

You can use `TestReports.test("pkgname")` just like you would use `Pkg.test("pkgname")`.
It creates a `testlog.xml` file in the current directory containing the results.


### Using directly
I actually don't recommend using this directly in your tests.
It is more flexible to just keep using the default testset type,
and then use something like the Runner script to generate a wrapper of your tests with this testset around it.

### Using with named testset types
I don't know how well this will work with named testset types.
If they act like the DefaultTestSet then everything should be fine.
But if they don't push themselves on to their parents testsets when the fininish then we will not be able to see their results.

