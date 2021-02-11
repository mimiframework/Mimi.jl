## Explanations: Models as Packages

## Models as Packages

[Pkg](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html) (more detail [here](https://julialang.github.io/Pkg.jl/v1/) is Julia's builtin package manager, and handles operations such as installing, updating and removing packages. When a model, or model version, is up and running it is often convenient to set it up as a julia Package using the steps described [here](https://julialang.github.io/Pkg.jl/v1/creating-packages/). This page describes that:

**"A package is a project with a `name`, `uuid` and version entry in the `Project.toml` file, and a `src/PackageName.jl` file that defines the module `PackageName`. This file is executed when the package is loaded.**

The final step of creating a package is Registering a Package, either in the General Registry as described at the bottom of the Creating Packages page, or our Mimi Registry as described below, this final step is not required in order to use the `Pkg` interface.  

### Example

The [MimiDICE2016](https://github.com/AlexandrePavlov/MimiDICE2016.jl) model is currently organized as a Package, but it is not registered.  Still, as it's README instructs, it can be accessed by:

Running the following command at the julia package REPL:
```julia
pkg> add https://github.com/AlexandrePavlov/MimiDICE2016.jl
```
Now you can use `MimiDICE2016` and its exported API:
```julia
using MimiDICE2016
m = MimiDICE2016.get_model()
run(m)
```

## The Mimi Registry

The Mimi Registry is a custom [Registry](https://julialang.github.io/Pkg.jl/v1/registries/) maintained by the Mimi development team that colocates several Mimi models in one central registry in the same way julia colates packages in the General Registry, where `Mimi` and other packages you commonly may use are located. While the development team maintains this registry and has some basic requirements such as continuous integration tesing (CI) and proper package structure as dictated by julia, they do not claim responsibility or knowledge of the content or quality of the models themselves. 

If you are interested in adding a model to the Mimi Registry, please be in touch with the Mimi development team by opening an [Issue on the Registry](https://github.com/mimiframework/MimiRegistry/issues) and/or a question on the [Mimi forum](https://forum.mimiframework.org) if you do not receive a timely response. We will aim to create a standard guide for this process soon.

### Example

The [MimiDICE2010] model is registered with the Mimi Registry, and thus can be accessed by:

Running the following command at the julia package REPL (only required once):
```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```
Followed by adding the package:
```julia
pkg> add MimiDICE2010
```
Now you can use `MimiDICE2010` and its exported API:
```julia
using MimiDICE2010
m = MimiDICE2010.get_model()
run(m)
```
