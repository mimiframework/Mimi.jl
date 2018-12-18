using Documenter, Mimi

makedocs(
    modules = [Mimi],
	format = :html,
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
        "User Guide" => "userguide.md",
		"Tutorials Intro" => "tutorials_detailed\tutorial_main.md",
		"Tutorial 1: Run an Existing Model " => "tutorials_detailed\tutorial_main.md",
		"Tutorial 2: Modfiy an Existing Model" => "tutorials_detailed\tutorial_main.md",
		"Tutorial 3: Create a Model" => "tutorials_detailed\tutorial_main.md",
		"Tutorial 4: MCS Functionality" => "tutorials_detailed\tutorial_main.md",

		"FAQ" => "faq.md",
		"Reference" => "reference.md",
		"Integration Guide: Port to v0.5.0" => "integrationguide.md"]
)

deploydocs(
    deps = nothing,
    make = nothing,
	target = "build",
    repo = "github.com/anthofflab/Mimi.jl.git",
    julia = "1.0"
)
