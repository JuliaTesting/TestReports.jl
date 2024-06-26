# Library

## Contents

```@contents
Pages = ["library.md"]
```

## Public

Documentation for `TestReports.jl`'s public interface.

```@docs
TestReports.test
TestReports.RUNNER_SCRIPT
record_testset_property
record_test_property
ReportingTestSet
any_problems
report
```

## Private

Package internals documentation.

### Report Generation

```@autodocs
Modules = [TestReports]
Pages   = ["runner.jl"]
Public = false
Filter = t -> !(t in (TestReports.test, TestReports.RUNNER_SCRIPT))
```

### TestSets

```@autodocs
Modules = [TestReports]
Pages   = ["testsets.jl"]
Public = false
```

### XML Writing

```@autodocs
Modules = [TestReports]
Pages   = ["to_xml.jl"]
Public = false
```

## Index

```@index
Pages = ["library.md"]
```
