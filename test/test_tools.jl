using Base.Test
using Mimi

@test Mimi.prettifyStringForLabels("camelCaseBasic") == "Camel Case Basic"
@test Mimi.prettifyStringForLabels("camelWithAOneLetterWord") == "Camel With A One Letter Word"
@test Mimi.prettifyStringForLabels("snake_case_basic") == "Snake Case Basic"
@test Mimi.prettifyStringForLabels("_snake__case__weird_") == "Snake Case Weird"
