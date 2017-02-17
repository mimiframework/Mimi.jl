if Pkg.installed("InfoZIP") == nothing
    Pkg.add("InfoZIP")
end

using Mimi
using InfoZIP
using Compat

function isa_url(x)
    return startswith(x, "https:")
end

#list of URLs of branches of packages to test
dependencies = [
"https://github.com/davidanthoff/fund.jl/archive/ee1c3adabacfecbb284a0fe60aae2e3b87946aa6.zip"
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
            process = string(tmp_path, package_name, "/test/runtests.jl")
        else
            package_name = basename(d)
            process = string(d, "/test/runtests.jl")
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
