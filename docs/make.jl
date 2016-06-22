using Documenter, Mimi

makedocs()

deploydocs(
    repo = "github.com/anthofflab/Mimi.jl.git",
    julia = "0.4"
)
