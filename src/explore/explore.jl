## Mimi UI
## Lisa Rennels, David Anthoff, Richard Plevin
## University of California, Berkeley
## January 25, 2018

#start Blink window
using Blink
w = Blink.Window()

#load main html file
# joinpath(@__DIR__, "main.html")
loadfile(w, abspath("main.html"))

#refresh variable list
@js w refreshVarList()
