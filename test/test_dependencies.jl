using Mimi

Pkg.add("InfoZIP")

#list of URLs of branches of packages to test
dependencies = [
"https://github.com/davidanthoff/fund.jl/archive/master.zip"
]

#list of failed tests to build as you go
errors = []
#make a temporary directory to run the tests in
tmp_path = joinpath(dirname(@__FILE__),"tmp_testing/")
mkdir(tmp_path)
cd(tmp_path)

#loop through each dependent package
for url in dependencies
  #download the package
  download(url)
  zip_name = chomp(basename(url))
  unzip(zip_name, tmp_path)
  rm(string(tmp_path, zip_name))
  package_name = chomp(readall(`ls`))
  #test the package
  try
    include(string(tmp_path, package_name, "/test/runtests.jl"))
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
if num_errors == 1
  println("1 test failed:")
else
  println("$num_errors tests failed:")
end

for item in errors
  package_name, error = item
  println("error in $package_name:")
  println(error)
end
