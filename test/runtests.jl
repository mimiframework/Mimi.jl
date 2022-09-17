using TestItemRunner
import Electron

Electron.prep_test_env()

@run_package_tests

# We need these for the doctests. We install them before we load any
# package so that we don't run into precompile problems
# Pkg.add(PackageSpec(url="https://github.com/fund-model/MimiFUND.jl", rev="master"))
# Pkg.add(PackageSpec(url="https://github.com/anthofflab/MimiDICE2010.jl", rev="master"))


# @info("doctests")
# @time doctest(Mimi)

# for app in Electron.applications()
#     close(app)
# end
