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
    println(fh, ts)
end
"""

run(`$(Base.julia_cmd()) -e $script`)
