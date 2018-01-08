#!julia

testfilename = shift!(ARGS)

#testfile_str = String(read(testfilename))

script = """
using Base.Test
using TestReports
ts = @testset ReportingTestSet "" begin
    include("$testfilename")
end

open("testlog.xml","w") do fh
    print(fh, report(ts))
end
exit(any_problems(ts))
"""

run(`$(Base.julia_cmd()) -e $script`)
