# Advanced How-to Guide: Reducing Time to First Result

Building and running a Mimi model for the first time in a fresh Julia session is
dominated by compilation, not by the model's arithmetic. A large model can take
tens of seconds on its first `run` and about a second on its second. Mimi itself
precompiles its model definition, build and run machinery, but the `run_timestep`
and `init` functions that [`@defcomp`](@ref) generates belong to *your* package,
and only your package can arrange for them to be compiled ahead of time.

The tool for this is [PrecompileTools.jl](https://github.com/JuliaLang/PrecompileTools.jl).
Add it as a dependency, and add a workload that exercises your model:

```julia
using PrecompileTools

@compile_workload begin
    m = get_model()
    run(m)
end
```

Everything Julia compiles while that block runs is saved into your package's
precompile cache, so your users do not pay for it again.

## When the model cannot be run during precompilation

Running the model in the workload is the best option, because it also caches the
surrounding machinery. Sometimes it is not possible — most often because the
model's input data is a large download that must not happen at package build
time.

For those cases, `Mimi.precompile_model` compiles every component's `init` and
`run_timestep` for a model *without* running it:

```julia
@compile_workload begin
    Mimi.precompile_model(get_model())
end
```

It builds the model if it has not been built already, recurses into composite
components, and works on a `MarginalModel` as well as a `Model`. It returns the
number of functions it submitted for compilation, which is handy as a sanity
check while you are setting the workload up.

Building a model does not touch component input data — that happens in `init`,
at run time — so this works even when the data is unavailable.

## What is and is not reusable

A component's compiled code is tied to the model it was built in. The signature
of its `run_timestep` depends on:

  * the model's time dimension, which is carried in the type as
    `FixedTimestep{FIRST, STEP, LAST}` or `VariableTimestep{(years...)}`, so two
    models with different time horizons, or one uniform and one not, need
    separate compilations;
  * the component's `first` and `last` placement in the model, because each
    component receives a timestep shifted to its own bounds;
  * the model's *full* set of dimensions, since the `d` argument is a named tuple
    of all of them, not only the ones the component declares;
  * the model's number type.

This is why the workload has to construct a model rather than work from the
component definitions alone. It also means a workload does not have to build
exactly the model your users will build — only one that produces the same types.
If your package offers several configurations that differ in just a few
components, a workload covering one configuration will still cover the components
the others share with it.

## Letting users opt out

A thorough workload can add noticeably to your package's precompilation time.
That cost is paid once per install or update rather than per session, so it is
usually worth it, but users can switch it off by putting the following in their
`LocalPreferences.toml`:

```toml
[YourPackage]
precompile_workload = false
```
