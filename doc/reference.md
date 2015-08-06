# Mimi


---

<a id="function__addcomponent.1" class="lexicon_definition"></a>
#### addcomponent [¶](#function__addcomponent.1)

Add a component to a model.


*source:*
[Mimi\src\Mimi.jl:214](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L214)

---

<a id="function__connectparameter.1" class="lexicon_definition"></a>
#### connectparameter [¶](#function__connectparameter.1)

Bind the parameter of one component to a variable in another component.



*source:*
[Mimi\src\Mimi.jl:271](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L271)

---

<a id="method__components.1" class="lexicon_definition"></a>
#### components(m::Model) [¶](#method__components.1)

List all the components in a given model.


*source:*
[Mimi\src\Mimi.jl:153](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L153)

---

<a id="method__getdataframe.1" class="lexicon_definition"></a>
#### getdataframe(m::Model, component::Symbol, name::Symbol) [¶](#method__getdataframe.1)

Return the values for a variable as a DataFrame.


*source:*
[Mimi\src\Mimi.jl:299](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L299)

---

<a id="method__run.1" class="lexicon_definition"></a>
#### run(m::Model) [¶](#method__run.1)

Run the model once.


*source:*
[Mimi\src\Mimi.jl:329](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L329)

---

<a id="method__setleftoverparameters.1" class="lexicon_definition"></a>
#### setleftoverparameters(m::Model, parameters::Dict{Any, Any}) [¶](#method__setleftoverparameters.1)

Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary.


*source:*
[Mimi\src\Mimi.jl:277](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L277)

---

<a id="method__setparameter.1" class="lexicon_definition"></a>
#### setparameter(m::Model, component::Symbol, name::Symbol, value) [¶](#method__setparameter.1)

Set the parameter of a component in a model to a given value.


*source:*
[Mimi\src\Mimi.jl:219](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L219)

---

<a id="method__variables.1" class="lexicon_definition"></a>
#### variables(m::Model, componentname::Symbol) [¶](#method__variables.1)

List all the variables in a component.


*source:*
[Mimi\src\Mimi.jl:160](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L160)

---

<a id="macro___defcomp.1" class="lexicon_definition"></a>
#### @defcomp(name, ex) [¶](#macro___defcomp.1)

Define a new component.


*source:*
[Mimi\src\Mimi.jl:368](https://github.com/davidanthoff/Mimi.jl/tree/b2fc0ecd9caf5eefbe20673c26cd35cb0e1404c6/src\Mimi.jl#L368)

