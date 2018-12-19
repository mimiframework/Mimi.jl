using Documenter, Mimi

makedocs(
    modules = [Mimi],
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
		"User Guide" => "userguide.md",
		"Tutorials" => Any[
			"Introduction" => "tutorials\tutorial_main.md",
			"1. Run an Existing Model " => "tutorials\tutorial_main.md",
			"2. Modfiy an Existing Model" => "tutorials\tutorial_main.md",
			"3. Create a Model" => "tutorials\tutorial_main.md",
			"4. MCS Functionality" => "tutorials\tutorial_main.md"
		],
		"FAQ" => "faq.md",
		"Reference" => "reference.md",
		"Integration Guide: Port to v0.5.0" => "integrationguide.md"]
)

deploydocs(
    repo = "github.com/anthofflab/Mimi.jl.git",
)
