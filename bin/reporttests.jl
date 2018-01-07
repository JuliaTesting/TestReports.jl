#!julia

testfilename = shift!(ARGS)

#testfile_str = String(read(testfilename))

"""
using Base.Test
using TestReports
ts = @testset ReportingTestSet "" begin
    include("$testfilename")
end

open("testlog.xml","w") do fh
    println(fh, ts)
end
""" |> include_string



