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

### Runner Script
