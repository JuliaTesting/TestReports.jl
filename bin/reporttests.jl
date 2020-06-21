#!julia

testfilename = popfirst!(ARGS)

#testfile_str = String(read(testfilename))

script = """
using Test
using TestReports
ts = @testset ReportingTestSet "" begin
    include($(repr(testfilename)))
end

open("testlog.xml","w") do fh
    print(fh, report(ts))
end
exit(any_problems(ts))
"""

run(`$(Base.julia_cmd()) -e $script`)
