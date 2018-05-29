using Mimi
include("../../../wip/load_empirical_dist.jl")

excel_file = joinpath(@__DIR__, "RB-ECS-distribution.xls")
d = load_empirical_dist(excel_file, "Sheet1!A2:A1001", "Sheet1!B2:B1001")
