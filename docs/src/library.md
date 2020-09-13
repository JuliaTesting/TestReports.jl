# Library

## Contents

```@contents
Pages = ["library.md"]
```

## Public

Documentation for `TestReports.jl`'s public interface.

```@docs
TestReports.test
recordproperty
ReportingTestSet
any_problems
report
```

## Private

Package internals documentation.

### Report Generation

```@docs
TestReports.checkinstalled!
TestReports.gettestfilepath
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
