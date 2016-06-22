# Mimi


---

<a id="function__addcomponent.1" class="lexicon_definition"></a>
#### Mimi.addcomponent [¶](#function__addcomponent.1)
Add a component to a model.


*source:*
[Mimi\src\Mimi.jl:224](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L224)

---

<a id="function__connectparameter.1" class="lexicon_definition"></a>
#### Mimi.connectparameter [¶](#function__connectparameter.1)
Bind the parameter of one component to a variable in another component.



*source:*
[Mimi\src\Mimi.jl:306](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L306)

---

<a id="method__components.1" class="lexicon_definition"></a>
#### components(m::Mimi.Model) [¶](#method__components.1)
List all the components in a given model.


*source:*
[Mimi\src\Mimi.jl:154](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L154)

---

<a id="method__connectparameter.1" class="lexicon_definition"></a>
#### connectparameter(target::Mimi.ComponentReference,  source::Mimi.ComponentReference,  name::Symbol) [¶](#method__connectparameter.1)
Connect two components as `connectparameter(reference1, reference2, name)`.


*source:*
[Mimi\src\references.jl:37](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\references.jl#L37)

---

<a id="method__connectparameter.2" class="lexicon_definition"></a>
#### connectparameter(target::Mimi.ComponentReference,  target_name::Symbol,  source::Mimi.ComponentReference,  source_name::Symbol) [¶](#method__connectparameter.2)
Connect two components as `connectparameter(reference1, name1, reference2, name2)`.


*source:*
[Mimi\src\references.jl:30](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\references.jl#L30)

---

<a id="method__getdataframe.1" class="lexicon_definition"></a>
#### getdataframe(m::Mimi.Model,  component::Symbol,  name::Symbol) [¶](#method__getdataframe.1)
Return the values for a variable as a DataFrame.


*source:*
[Mimi\src\Mimi.jl:334](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L334)

---

<a id="method__getindex.1" class="lexicon_definition"></a>
#### getindex(c::Mimi.ComponentReference,  name::Symbol) [¶](#method__getindex.1)
Get a variable reference as `reference[name]`.


*source:*
[Mimi\src\references.jl:53](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\references.jl#L53)

---

<a id="method__run.1" class="lexicon_definition"></a>
#### run(m::Mimi.Model) [¶](#method__run.1)
Run the model once.


*source:*
[Mimi\src\Mimi.jl:368](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L368)

---

<a id="method__setleftoverparameters.1" class="lexicon_definition"></a>
#### setleftoverparameters(m::Mimi.Model,  parameters::Dict{Any, Any}) [¶](#method__setleftoverparameters.1)
Set all the parameters in a model that don't have a value and are not connected
to some other component to a value from a dictionary.


*source:*
[Mimi\src\Mimi.jl:313](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L313)

---

<a id="method__setparameter.1" class="lexicon_definition"></a>
#### setparameter(c::Mimi.ComponentReference,  name::Symbol,  value) [¶](#method__setparameter.1)
Set a component parameter as `setparameter(reference, name, value)`.


*source:*
[Mimi\src\references.jl:16](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\references.jl#L16)

---

<a id="method__setparameter.2" class="lexicon_definition"></a>
#### setparameter(m::Mimi.Model,  component::Symbol,  name::Symbol,  value) [¶](#method__setparameter.2)
Set the parameter of a component in a model to a given value.


*source:*
[Mimi\src\Mimi.jl:229](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L229)

---

<a id="method__unitcheck.1" class="lexicon_definition"></a>
#### unitcheck(one::AbstractString,  two::AbstractString) [¶](#method__unitcheck.1)
Default string, string unit check function


*source:*
[Mimi\src\Mimi.jl:297](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L297)

---

<a id="method__variables.1" class="lexicon_definition"></a>
#### variables(m::Mimi.Model,  componentname::Symbol) [¶](#method__variables.1)
List all the variables in a component.


*source:*
[Mimi\src\Mimi.jl:171](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L171)

---

<a id="type__componentreference.1" class="lexicon_definition"></a>
#### Mimi.ComponentReference [¶](#type__componentreference.1)
A container for a component, for interacting with it within a model.


*source:*
[Mimi\src\references.jl:8](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\references.jl#L8)

---

<a id="macro___defcomp.1" class="lexicon_definition"></a>
#### @defcomp(name, ex) [¶](#macro___defcomp.1)
Define a new component.


*source:*
[Mimi\src\Mimi.jl:423](https://github.com/anthofflab/Mimi.jl/tree/fb9ff73b04a34463bd242123f4bf6f4752de05b9/src\Mimi.jl#L423)

