using Documenter, Mimi

makedocs(
    modules = [Mimi],
	format = :html,
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
        "User Guide" => "userguide.md",
		"Tutorial" => "tutorial.md",
		"FAQ" => "faq.md",
		"Reference" => "reference.md",
		"Integration Guide" => "integrationguide.md"]
)

deploydocs(
    deps = nothing,
    make = nothing,
	target = "build",
    repo = "github.com/anthofflab/Mimi.jl.git",
    julia = "1.0"
)
