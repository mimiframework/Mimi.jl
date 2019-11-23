using Pkg

if haskey(ENV, "GITHUB_ACTIONS") && ENV["GITHUB_ACTIONS"] == "true"
    Pkg.Registry.add("https://github.com/mimiframework/MimiRegistry")
end
