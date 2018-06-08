module RegionTutorialBenchmarks

const tutorialpath = normpath(joinpath(@__DIR__, "..", "examples", "tutorial"))
const tworegionpath = joinpath(tutorialpath, "02-two-region-model")
const oneregionpath = joinpath(tutorialpath, "01-one-region-model")

include(joinpath(oneregionpath, "one-region-model.jl"))
include(joinpath(tworegionpath, "main.jl"))

end #module