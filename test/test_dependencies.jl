if Pkg.installed("InfoZIP") == nothing
    Pkg.add("InfoZIP")
end

using Mimi
using InfoZIP

function isa_url(x)
    return startswith(x, "https:")
end

#list of URLs of branches of packages to test
dependencies = [
    "https://github.com/lrennels/fund/archive/366c383d4a35454489b5c74a0e471241a78637e0.zip",
    "https://github.com/lrennels/mimi-rice-2010.jl/archive/811ac52e630f640311f6ceffc229885a5f156090.zip"
]

function run_dependency_tests(dependencies=dependencies)
    #list of failed tests to build as you go
    errors = []
    #make a temporary directory to run the tests in
    tmp_path = joinpath(dirname(@__FILE__),"tmp_testing/")
    mkdir(tmp_path)

    #loop through each dependent package
    for d in dependencies
        if  isa_url(d)
            zip_name = chomp(basename(d))
            zip_file_path = joinpath(tmp_path, zip_name)
            download(d, zip_file_path)
            InfoZIP.unzip(zip_file_path, tmp_path)
            rm(zip_file_path)
            #find the name of the unzipped package (this only works if the zip archive only has one directory, the package)
            package_name = readdir(tmp_path)[1]
            file_path = string(tmp_path, package_name)
        else
            package_name = basename(d)
            file_path = d
        end

        #first check for mimitests.jl, if not found default to runtests.jl
        if "mimitests.jl" in readdir(string(file_path, "/test/"))
            process = string(file_path, "/test/mimitests.jl")
        else
            process = string(file_path, "/test/runtests.jl")
        end

        #test the package
        try
            run(`$JULIA_HOME/julia $process`)
        catch e
            append!(errors, [(package_name, e)])
        end
        #delete current package before testing next one (if it was a downloaded package)
        if isa_url(d)
            rm(joinpath(tmp_path, package_name), recursive=true)
        end
    end

    #remove the temporary directory
    rm(tmp_path, recursive=true)

    #report the errors that occurred
    num_errors = length(errors)
    error_message = "Failed tests: $num_errors"

    for (package_name, error) in errors
        error_message = string(error_message, "\n", "error in $package_name:", error)
    end

    if num_errors > 0
        error(error_message)
    else
        println("All dependency tests passed.")
    end
end
