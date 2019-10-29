using Pkg

packages_to_test = [
    ("https://github.com/anthofflab/MimiRICE2010.jl.git", "v2.0.3", "MimiRICE2010"),
    ("https://github.com/fund-model/MimiFUND.jl.git", "v3.11.8", "MimiFUND")
]

null = Base.CoreLogging.NullLogger() # need to supress warnings to prevent Travis log overflow from int indexing
for (pkg_url, pkg_rev, pkg_name) in packages_to_test
    mktempdir() do folder
        Pkg.activate(folder)

        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..", "..")))
        Base.CoreLogging.with_logger(null) do
            Pkg.add(PackageSpec(url=pkg_url, rev=pkg_rev))
        end

        Pkg.test(pkg_name)
    end
end
