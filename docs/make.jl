using Documenter, Mimi

makedocs(
    modules = [Mimi],
	format = Documenter.Formats.HTML,
	sitename = "Mimi.jl",
	pages = [
		"Home" => "index.md",
		"Installation Guide" => "installation.md",
		"Tutorial" => "tutorial.md",
		"User Guide" => "userguide.md",
		"FAQ" => "faq.md",
		"Reference" => "reference.md"]
)

deploydocs(
    deps = nothing,
    make = nothing,
    repo = "github.com/anthofflab/Mimi.jl.git",
    julia = "0.5"
)
