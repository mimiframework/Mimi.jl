using Mimi

#list of URLs of branches of packages to test
dependencies = ["https://github.com/davidanthoff/fund.jl/archive/master.zip"]

#list of failed tests to build as you go
errors = []

#make a temporary directory to run the tests in
run(`mkdir tmp_testing`)
cd("tmp_testing")

#loop through each dependent package
for url in dependencies
  #download the package
  run(`wget $url`)
  zip_name = chomp(readall(`basename $url`))
  run(`unzip -x $zip_name`)
  run(`rm $zip_name`)
  package_name = chomp(readall(`ls`))
  #test the package
  try
    Pkg.test(package_name)
  catch e
    append!(errors, [(package_name, e)])
  end
  #delete current package before testing next one
  run(`rm -rf *`)
end

#remove the temporary directory
cd("../")
run(`rm -rf tmp_testing`)

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
