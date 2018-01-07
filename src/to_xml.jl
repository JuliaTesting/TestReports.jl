# Format is defined by
# https://www.ibm.com/support/knowledgecenter/en/SSQ2R2_9.5.0/com.ibm.rsar.analysis.codereview.cobol.doc/topics/cac_useresults_junit.html
# http://help.catchsoftware.com/display/ET/JUnit+Format

function set_attribute!(node, attr, val)
    link!(node, AttributeNode(attr, string(val)))
end

function testsuites_xml(name, id, ntests, nfails, nerrors, x_children)
    x_testsuite = ElementNode("testsuites")
    link!.(x_testsuite, x_children)
    set_attribute!(x_testsuite, "name", name)
    set_attribute!(x_testsuite, "id", id)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    x_testsuite
end


function testsuite_xml(name, id, ntests, nfails, nerrors, x_children)
    x_testsuite = ElementNode("testsuite")
    link!.(x_testsuite, x_children)
    set_attribute!(x_testsuite, "name", name)
    set_attribute!(x_testsuite, "id", id)
    set_attribute!(x_testsuite, "tests", ntests)
    set_attribute!(x_testsuite, "failures", nfails)
    set_attribute!(x_testsuite, "errors", nerrors)
    x_testsuite
end

function testcase_xml(name, id, x_children)
    x_tc = ElementNode("testcase")
    link!.(x_tc, x_children)
    set_attribute!(x_tc, "name", name)
    set_attribute!(x_tc, "id", id)
    x_tc
end

testcase_xml(v::Result, childs) = testcase_xml(string(v.orig_expr), "_testcase_id_", childs)

function failure_xml(message, test_type, content)
    x_fail = ElementNode("failure")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type", test_type)
    link!(x_fail, TextNode(content))
    x_fail
end

function skip_xml()
    ElementNode("skip")
end

function error_xml(message, ex_type, content)
    x_fail = ElementNode("error")
    set_attribute!(x_fail, "message", message)
    set_attribute!(x_fail, "type",  ex_type)
    link!(x_fail, TextNode(content))
    x_fail
end



#####################

function xml_report(ts::AbstractTestSet)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    x_testsuites = map(ts.results) do result
        x_testsuite, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors;
        x_testsuite
    end

    xdoc = XMLDocument()
    root = setroot!(xdoc, testsuites_xml(ts.description,
                                         string(now),
                                         total_ntests,
                                         total_nfails,
                                         total_nerrors,
                                         x_testsuites))
    
    xdoc
end

"testsuite"
function to_xml(ts::AbstractTestSet)
    total_ntests = 0
    total_nfails = 0
    total_nerrors = 0
    x_testcases = map(ts.results) do result
        x_testcase, ntests, nfails, nerrors = to_xml(result)
        total_ntests += ntests
        total_nfails += nfails
        total_nerrors += nerrors
        x_testcase
    end

    x_testsuite = testsuite_xml(ts.description, "_id_", total_ntests, total_nfails, total_nerrors, x_testcases)
    x_testsuite, total_ntests, total_nfails, total_nerrors
end


function to_xml(res::Pass)
    x_testcase = testcase_xml("pass (info lost)", "_testcase_id_", [])
    x_testcase, 1, 0, 0
end

function to_xml(v::Fail)
    x_failure = failure_xml(string(v.data), string(v.test_type), string(v))
    x_testcase = testcase_xml(v, [x_failure])
    x_testcase, 1, 1, 0
end

function to_xml(v::Broken)
    x_testcase = testcase_xml(v, [skip_xml()]) # it is not actually skipped
    x_testcase, 0, 0, 0
end

function to_xml(v::Error)
    buff = IOBuffer()
    Base.show_backtrace(buff, scrub_backtrace(backtrace()))
    backtrace_str = String(take!(buff))

    x_testcase = error_xml(string(v.value), typeof(v.value), backtrace_str)
    x_testcase, 0,0,1
end


