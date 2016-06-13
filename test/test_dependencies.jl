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
  zip_name = chomp(basename(url))
  file_path = joinpath(tmp_path, zip_name)
  download(url, file_path)
  unzip(file_path, tmp_path)
  rm(file_path)
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
  error_message = string("\n", error_message, "error in $package_name:", error)
end

if num_errors > 0
  error(error_message)
end
