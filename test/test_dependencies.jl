using Mimi
using InfoZIP

#list of URLs of branches of packages to test
dependencies = [
"https://github.com/davidanthoff/fund.jl/archive/master.zip"
]

#list of failed tests to build as you go
errors = []
#make a temporary directory to run the tests in
tmp_path = joinpath(dirname(@__FILE__),"tmp_testing")
mkdir(tmp_path)

#loop through each dependent package
for url in dependencies
  #download the package
  download(url, tmp_path)
  zip_name = chomp(basename(url))
  unzip(zip_name, tmp_path)
  rm(string(tmp_path, zip_name))
  package_name = chomp(readir())
  #test the package
  try
    process = string(tmp_path, package_name, "/test/runtests.jl")
    run(`julia $process`)
  catch e
    append!(errors, [(package_name, e)])
  end
  #delete current package before testing next one
  rm(string(tmp_path, package_name), recursive=true)
end

#remove the temporary directory
rm(tmp_path, recursive=true)

#report the errors that occurred
num_errors = length(errors)
error_message = "Failed tests: $num_errors"

for (package_name, error) in errors
  error_message = string(error_message, "error in $package_name:", error, "\n")
end

if num_errors > 0
  error(error_message)
end
