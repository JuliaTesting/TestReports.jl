using Printf

# Format is defined by
# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_14.2.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html
# http://help.catchsoftware.com/display/ET/JUnit+Format

"""
   format_period_for_xml(time::Millisecond)

Formats a millisecond value into a string in seconds with 3 decimal places.

`@sprintf` is used to ensure that value does not use scientific notification,
which is not allowed in an XML decimal.

Methods for other `Period`s have not been written as are not currently required.
"""
format_period_for_xml(time::Millisecond) = @sprintf("%.3f", time.value/1000)

"""
    set_attribute!(node, attr, val)
    set_attribute!(node, attr, val::Period)

Add the attritube with name `attr` and value `val` to `node`.

If `val` is of type `Period`, format with `format_period_for_xml`.
"""
set_attribute!(node, attr, val) = setindex!(node, string(val), attr)
set_attribute!(node, attr, val::Period) = setindex!(node, format_period_for_xml(val), attr)

"""
    testsuites_xml(ntests, nfails, nerrors, x_children)

Create the testsuites element of a JUnit XML.
"""
function testsuites_xml(ntests, nfails, nerrors, x_children)
    x_testsuite = ElementNode("testsuites")
    link!.(Ref(x_testsuite), x_children)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    x_testsuite
end

"""
    testsuite_xml(name, ntests, nfails, nerrors, x_children)

Create a testsuite element of a JUnit XML.
"""
function testsuite_xml(name, ntests, nfails, nerrors, x_children, time, timestamp, hostname)
    x_testsuite = ElementNode("testsuite")
    link!.(Ref(x_testsuite), x_children)
    set_attribute!(x_testsuite, "name", name)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    set_attribute!(x_testsuite, "time", time)
    set_attribute!(x_testsuite, "timestamp", timestamp)
    set_attribute!(x_testsuite, "hostname", hostname)
    x_testsuite
end

"""
    testcase_xml(name, id, x_children)

Create a testcase element of a JUnit XML.

This is the generic form (with name, id and children) that is used by other methods.
"""
function testcase_xml(name, id, x_children)
    x_tc = ElementNode("testcase")
    link!.(Ref(x_tc), x_children)
    set_attribute!(x_tc, "name", name)
    set_attribute!(x_tc, "id", id)
    x_tc
end

"""
    testcase_xml(v::Result, childs)

Create a testcase element of a JUnit XML for the result `v`.

The original expression of the test is used as the name, whilst the id is defaulted to
_testcase_id_.
"""
testcase_xml(v::Result, childs) = testcase_xml(string(v.orig_expr), "_testcase_id_", childs)

"""
    failure_xml(message, test_type, content)

Create a failure node (which will be the child of a testcase).
"""
function failure_xml(message, test_type, content)
    x_fail = ElementNode("failure")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type", test_type)
    link!(x_fail, TextNode(content))
    x_fail
end

"""
    skip_xml()

Create a skip node (which will be the child of a testcase).
"""
function skip_xml()
    ElementNode("skip")
end

"""
    failure_xml(message, test_type, content)

Create an error node (which will be the child of a testcase).
"""
function error_xml(message, ex_type, content)
    x_fail = ElementNode("error")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type",  ex_type)
    link!(x_fail, TextNode(content))
    x_fail
end

#####################

"""
    report(ts::AbstractTestSet)

Will produce an `XMLDocument` that contains a report about the `TestSet`'s results.
This report will follow the JUnit XML schema.

To report correctly, the `TestSet` must have the following structure:

    AbstractTestSet
      └─ AbstractTestSet
           └─ AbstractResult

That is, the results of the top level `TestSet` must all be `AbstractTestSet`s,
and the results of those `TestSet`s must all be `Result`s.

Additionally, all of the `AbstractTestSet`s must have both `description` and
`results` fields.
"""
function report(ts::AbstractTestSet)
    check_ts(ts)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    testsuiteid = 0 # ID increments from 0
    x_testsuites = map(ts.results) do result
        x_testsuite, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors;
        set_attribute!(x_testsuite, "id", testsuiteid)
        testsuiteid += 1
        x_testsuite
    end

    xdoc = XMLDocument()
    root = setroot!(xdoc, testsuites_xml(total_ntests,
                                         total_nfails,
                                         total_nerrors,
                                         x_testsuites))
    
    xdoc
end

"""
    check_ts(ts::AbstractTestSet)

Throws an exception if `ts` does not have the right structure for `report` or if
the results of `ts` do not have both `description` or `results` fields.

See also: [`report`](@ref)
"""
function check_ts(ts::AbstractTestSet)
    !all(isa.(ts.results, AbstractTestSet)) && throw(ArgumentError("Results of ts must all be AbstractTestSets. See documentation for `report`."))
    for results_ts in ts.results
        !isa(results_ts.description, AbstractString) && throw(ArgumentError("description field of $(typeof(results_ts)) must be an AbstractString."))
        !all(isa.(results_ts.results, Result)) && throw(ArgumentError("Results of each AbstractTestSet in ts.results must all be Results. See documentation for `report`."))
    end
end

"""
    to_xml(ts::AbstractTestSet)

Create a testsuite node from a `AbstractTestSet`, by creating nodes for each result
in `ts.results`. For creating a JUnit XML, all results must be `AbstractResult`s, that is
they cannot be `AbstractTestSet`s, as the XML cannot have one testsuite nested inside
another.
"""
function to_xml(ts::AbstractTestSet)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    x_testcases = map(ts.results) do result
        x_testcase, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors
        # Set attributes which are common across result types
        set_attribute!(x_testcase, "classname", ts.description)
        set_attribute!(x_testcase, "time", time_taken(result)::Millisecond)
        # Set attributes which require variables in this scope
        (result isa Pass || result isa ReportingResult{Pass}) && set_attribute!(x_testcase, "name", x_testcase["name"] * " (Test $total_ntests)")
        x_testcase
    end

    x_testsuite = testsuite_xml(ts.description, total_ntests, total_nfails, total_nerrors, x_testcases, time_taken(ts)::Millisecond, start_time(ts)::DateTime, hostname(ts))
    add_testsuite_properties!(x_testsuite, ts)
    x_testsuite, total_ntests, total_nfails, total_nerrors
end

"""
    to_xml(res::Pass)
    to_xml(res::Fail)
    to_xml(res::Broken)
    to_xml(res::Error)
    to_xml(res::ReportingResult)

Create a testcase node from the result and return it along with
information on number of tests.
"""
function to_xml(res::Pass)
    x_testcase = testcase_xml("pass (info lost)", "_testcase_id_", [])
    x_testcase, 1, 0, 0  # Increment number of tests by 1
end

function to_xml(v::Fail)
    x_failure = failure_xml(get_failure_message(v), string(v.test_type), string(v))
    x_testcase = testcase_xml(v, [x_failure])
    x_testcase, 1, 1, 0  # Increment number of tests and number of failures by 1
end

function to_xml(v::Broken)
    x_testcase = testcase_xml(v, [skip_xml()]) # it is not actually skipped
    x_testcase, 0, 0, 0
end

function to_xml(v::Error)
    message, type = get_error_info(v)
    x_testcase = error_xml(message, type, v.backtrace)
    x_testcase, 0, 0, 1  # Increment number of errors by 1
end

to_xml(v::ReportingResult) = to_xml(v.result)

"""
    get_error_info(v::Error)

Return message and type of error for testcase attribute. Uses `test_type`
field to determine what caused the original error.
"""
function get_error_info(v::Error)
    if v.test_type == :test_nonbool
        msg = "Expression evaluated to non-Boolean"
        type = "Expression evaluated to non-Boolean"
    elseif v.test_type == :test_unbroken
        msg = "Got correct result, please change to @test if no longer broken."
        type = "Unexpected Pass"
    elseif v.test_type == :nontest_error
        msg = "Got exception outside of a @test"
        type = typeof(eval(Meta.parse(v.value)))
    else
        err = eval(Meta.parse(v.value))
        msg = sprint(showerror, err)
        type = typeof(err)
    end
    return msg, type
end

"""
get_failure_message(v::Fail)

Return message for failed test testcase attribute. Uses `test_type`
field to determine what caused the original failure.
"""
function get_failure_message(v::Fail)
    if v.test_type == :test
        # Normal test failure, use test data itself
        data = v.data === nothing ? "" : v.data  # Needed for V1.0
        return string(data)
    elseif v.test_type == :test_throws_nothing
        return "No exception thrown"
    elseif v.test_type == :test_throws_wrong
        return "Wrong exception type thrown"
    end
end

"""
    add_testsuite_properties!(x_testsuite, ts::AbstractTestSet)

Add all key value pairs in the `properties` field of a `AbstractTestSet` to the
corresponding testsuite xml element. This function assumes that the type of `ts`
has a `TestReports.properties` method defined.

See also: [`properties`](@ref)
"""
function add_testsuite_properties!(x_testsuite, ts::AbstractTestSet)
    properties_dict = properties(ts)
    if !isnothing(properties_dict) && !isempty(keys(properties_dict))
        x_properties = ElementNode("properties")
        for (name, value) in properties_dict
            x_property = ElementNode("property")
            set_attribute!(x_property, "name", name)
            set_attribute!(x_property, "value", value)
            link!(x_properties, x_property)
        end
        link!(x_testsuite, x_properties)
    end
    return x_testsuite
end