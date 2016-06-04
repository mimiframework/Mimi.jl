using Base.Test
using Mimi

dependencies = []

run(`mkdir tmp`)
cd("tmp")

for url in dependencies:
  run(`wget $url`)
  zip_name = chomp(readall(`basename $url`))
  run(`unzip -x $zip_name`)
  run(`rm $zip_name`)
  package_name = chomp(readall(`ls`))
  Pkg.test(package_name)
  run(`rm -rf *`)

run(`rm -rf tmp`)
