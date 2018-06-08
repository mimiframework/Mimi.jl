module RegionTutorialBenchmarks

const tutorialpath = normpath(joinpath(@__DIR__, "..", "examples", "tutorial"))
const tworegionpath = joinpath(tutorialpath, "02-two-region-model")
const oneregionpath = joinpath(tutorialpath, "01-one-region-model")

function run_oneregion()
    include(joinpath(oneregionpath, "one-region-model.jl"))
end

function run_tworegion()
    include(joinpath(tworegionpath, "main.jl"))
end

export run_oneregion, run_tworegion
end #module