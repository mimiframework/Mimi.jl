module TestTools

using Test
using Mimi

import Mimi:
    getproperty, pretty_string

#utils: pretty_string
@test pretty_string("camelCaseBasic") == pretty_string(:camelCaseBasic) == "Camel Case Basic"
@test pretty_string("camelWithAOneLetterWord") == pretty_string(:camelWithAOneLetterWord) == "Camel With A One Letter Word"
@test pretty_string("snake_case_basic") == pretty_string(:snake_case_basic) == "Snake Case Basic"
@test pretty_string("_snake__case__weird_") == pretty_string(:_snake__case__weird_) == "Snake Case Weird"

#utils: interpolate
stepsize = 2       
final = 10         
ts = 10
@test Mimi.interpolate(collect(0:stepsize:final), ts) == collect(0:stepsize/ts:final)

end #module
