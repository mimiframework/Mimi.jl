using Documenter, Mimi

makedocs(
    modules = [Mimi],
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
		"User Guide" => "userguide.md",
		"Tutorials" => Any[
			"Tutorials Intro" => "tutorials/tutorial_main.md",
			"1 Run an Existing Model" => "tutorials/tutorial_1.md",
			"2 Modify an Existing Model" => "tutorials/tutorial_2.md",
			"3 Create a Model" => "tutorials/tutorial_3.md",
			"4 MCS Functionality" => "tutorials/tutorial_4.md"
		],
		"FAQ" => "faq.md",
		"Reference" => "reference.md",
		"Integration Guide: Port to v0.5.0" => "integrationguide.md"],

		format = Documenter.HTML(prettyurls = get(ENV, "JULIA_NO_LOCAL_PRETTY_URLS", nothing) === nothing)
)

deploydocs(
    repo = "github.com/anthofflab/Mimi.jl.git",
)
