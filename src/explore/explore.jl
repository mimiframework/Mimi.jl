using Blink

w = Blink.Window()

# joinpath(@__DIR__, "main.html")

loadfile(w, abspath("main.html"))

data = ["Var 5", "Var 8"]

@js w refreshVarList($data)

Blink.tools(w)
