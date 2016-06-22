using Documenter, Mimi

makedocs(
    modules = [Mimi]
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material", "python-markdown-math"),
    repo = "github.com/anthofflab/Mimi.jl.git",
    julia = "0.4"
)
