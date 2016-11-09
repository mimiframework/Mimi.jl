if Pkg.installed("ZipFile") == nothing
    Pkg.add("ZipFile")
end

using Mimi
using ZipFile
using Compat

function unzip(inputfilename, outputpath=pwd())
    r = ZipFile.Reader(inputfilename)
    try
        for f in r.files
            outpath = joinpath(outputpath, f.name)
            if isdirpath(outpath)
                mkpath(outpath)
            else
                Base.open(outpath, "w") do io
                    write(io, readstring(f))
                end
            end
        end
    finally
        close(r)
    end
    nothing
end

#list of URLs of branches of packages to test
dependencies = [
"https://github.com/davidanthoff/fund.jl/archive/ee1c3adabacfecbb284a0fe60aae2e3b87946aa6.zip"
]

#list of failed tests to build as you go
errors = []
#make a temporary directory to run the tests in
tmp_path = joinpath(dirname(@__FILE__),"tmp_testing/")
mkdir(tmp_path)

#loop through each dependent package
for url in dependencies
  #download the package
  zip_name = chomp(basename(url))
  zip_file_path = joinpath(tmp_path, zip_name)
  download(url, zip_file_path)
  unzip(zip_file_path, tmp_path)
  rm(zip_file_path)
  #find the name of the unzipped package (this only works if the zip archive only has one directory, the package)
  package_name = readdir(tmp_path)[1]

  #test the package
  try
    process = string(tmp_path, package_name, "/test/runtests.jl")
    run(`julia $process`)
  catch e
    append!(errors, [(package_name, e)])
  end
  #delete current package before testing next one
  rm(joinpath(tmp_path, package_name), recursive=true)
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
