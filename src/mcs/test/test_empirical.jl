using Mimi

path = joinpath(dirname(@__FILE__), "RB-ECS-distribution.xls")
d = Mimi.EmpiricalDistribution(path, "Sheet1!A2:A1001", "Sheet1!B2:B1001")
