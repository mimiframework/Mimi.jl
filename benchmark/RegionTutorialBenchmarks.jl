const tutorialpath = normpath(joinpath(@__DIR__, "..", "examples", "tutorial"))
const multiregionpath = joinpath(tutorialpath, "02-multi-region-model")
const oneregionpath = joinpath(tutorialpath, "01-one-region-model")

function run_oneregion()
    include(joinpath(oneregionpath, "one-region-model.jl"))
end

function run_multiregion()
    include(joinpath(multiregionpath, "main.jl"))
end
