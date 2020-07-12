using TestsWithTestDeps, Dictionaries, Test

results = Dictionary(["result1"], [3])
@test simple_sum(1, 2) == results["result1"]