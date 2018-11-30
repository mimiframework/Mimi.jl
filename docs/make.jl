using Documenter, Mimi

makedocs(
    modules = [Mimi],
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
        "User Guide" => "userguide.md",
		"Tutorial" => "tutorial.md",
		"FAQ" => "faq.md",
		"Reference" => "reference.md",
		"Integration Guide: Port to v0.5.0" => "integrationguide.md"]
)

deploydocs(
    repo = "github.com/anthofflab/Mimi.jl.git",
)
