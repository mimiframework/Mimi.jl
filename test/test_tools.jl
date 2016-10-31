using Base.Test
using Mimi

@test Mimi.prettifystring("camelCaseBasic") == "Camel Case Basic"
@test Mimi.prettifystring("camelWithAOneLetterWord") == "Camel With A One Letter Word"
@test Mimi.prettifystring("snake_case_basic") == "Snake Case Basic"
@test Mimi.prettifystring("_snake__case__weird_") == "Snake Case Weird"
