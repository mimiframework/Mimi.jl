using Pkg

packages_to_test = [
    ("https://github.com/anthofflab/MimiRICE2010.jl.git", "v2.0.3", "MimiRICE2010"),
    ("https://github.com/fund-model/MimiFUND.jl.git", "v3.11.5", "MimiFUND")
]

for (pkg_url, pkg_rev, pkg_name) in packages_to_test
    mktempdir() do folder
        Pkg.activate(folder)

        Pkg.develop(joinpath(@__DIR__, "..", ".."))

        Pkg.add(PackageSpec(url=pkg_url, rev=pkg_rev))

        Pkg.test(pkg_name)
    end
end
