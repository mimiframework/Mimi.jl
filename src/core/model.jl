#
# User facing struct that unifies a ModelDef and a ModelInstance and delegates
# function calls to one or the other as appropriate.
#
using MacroTools

"""
    modeldef(m)

Return the `ModelDef` contained by Model `m`.
"""
modeldef(m::Model) = m.md

"""
    modelinstance(m::Model)

Return the `ModelInstance` contained by Model `m`.
"""
modelinstance(m::Model) = m.mi

"""
    modelinstance_def(m::Model)

Return the `ModelDef` of the `ModelInstance` contained by Model `m`.
"""
modelinstance_def(m::Model) = modeldef(modelinstance(m))

"""
    is_built(m::Model)

Return true if Model `m` is built, otherwise return false.
"""
is_built(m::Model) = !(dirty(m.md) || modelinstance(m) === nothing)

"""
    is_built(mm::MarginalModel)

Return true if `MarginalModel` `mm` is built, meaning both its `base` and `modified`
`Model`s are built, otherwise return false.
"""
is_built(mm::MarginalModel) = (is_built(mm.base) && is_built(mm.modified))

@delegate compinstance(m::Model, name::Symbol) => mi
@delegate has_comp(m::Model, name::Symbol) => md

@delegate number_type(m::Model) => md

@delegate internal_param_conns(m::Model) => md
@delegate external_param_conns(m::Model) => md

@delegate model_params(m::Model) => md
@delegate model_param(m::Model, comp_name::Symbol, param_name::Symbol; missing_ok = false) => md
@delegate model_param(m::Model, name::Symbol; missing_ok=false) => md

@delegate connected_params(m::Model) => md
@delegate unconnected_params(m::Model) => md
@delegate nothing_params(m::Model) => md

@delegate add_connector_comps!(m::Model) => md

"""
    connect_param!(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol, 
                    src_comp_name::Symbol, src_var_name::Symbol, 
                    backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, 
                    backup_offset::Union{Int, Nothing}=nothing)

Bind the parameter `dst_par_name` of one component `dst_comp_name` of model `m`
to a variable `src_var_name` in another component `src_comp_name` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `backup_offset` argument, which is only valid 
when `backup` data has been set, indicates that the backup data should be used for
a specified number of timesteps after the source component begins. ie. the value would be 
`1` if the destination componentm parameter should only use the source component 
data for the second timestep and beyond.
"""
@delegate connect_param!(m::Model, dst_comp_name::Symbol, dst_par_name::Symbol,
                        src_comp_name::Symbol, src_var_name::Symbol,
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, 
                        backup_offset::Union{Nothing, Int} = nothing) => md


"""
    connect_param!(m::Model, comp_name::Symbol, param_name::Symbol, model_param_name::Symbol;
                   check_attributes::Bool=true, ignoreunits::Bool=false))

Connect a parameter `param_name` in the component `comp_name` of composite `obj` to
the model parameter `model_param_name`.
"""
@delegate connect_param!(m::Model, comp_name::Symbol, param_name::Symbol, model_param_name::Symbol;
                        check_attributes::Bool=true, ignoreunits::Bool = false) => md

"""
    connect_param!(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol}, backup::Array; ignoreunits::Bool=false)

Bind the parameter `dst[2]` of one component `dst[1]` of model `m`
to a variable `src[2]` in another component `src[1]` of the same model
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `backup_offset` argument, which is only valid 
when `backup` data has been set, indicates that the backup data should be used for
a specified number of timesteps after the source component begins. ie. the value would be 
`1` if the destination componentm parameter should only use the source component 
data for the second timestep and beyond.

"""
function connect_param!(m::Model, dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol},
                           backup::Union{Nothing, Array}=nothing;
                           ignoreunits::Bool=false, backup_offset::Union{Int, Nothing} = nothing)
    connect_param!(m.md, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, backup_offset=backup_offset)
end

"""
    disconnect_param!(m::Model, comp_name::Symbol, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` in model `m`.
"""
@delegate disconnect_param!(m::Model, comp_name::Symbol, param_name::Symbol) => md

"""
    add_model_param!(m::Model, name::Symbol, value::ModelParameter)

Add an model parameter with name `name` and Model Parameter `value` to Model `m`.
"""
@delegate add_model_param!(m::Model, name::Symbol, value::ModelParameter) => md

"""
    add_model_param!(m: Model, name::Symbol, value::Number;
                    param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                    is_shared::Bool = false)

Create and add a model parameter with name `name` and Model Parameter `value` 
to Model `m`. The Model Parameter will be created with value `value`, dimensions
`param_dims` which can be left to be created automatically from the Model Def, and 
an is_shared attribute `is_shared` which defaults to false.
"""
@delegate add_model_param!(m::Model, name::Symbol,
                            value::Union{Number, AbstractArray, AbstractRange, Tuple};
                            param_dims::Union{Nothing,Array{Symbol}} = nothing) => md
"""
    add_model_param!(m::Model, name::Symbol,
                    value::Union{AbstractArray, AbstractRange, Tuple};
                    param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                    is_shared::Bool = false)

Create and add a model parameter with name `name` and Model Parameter `value` 
to Model `m`. The Model Parameter will be created with value `value`, dimensions
`param_dims` which can be left to be created automatically from the Model Def, and 
an is_shared attribute `is_shared` which defaults to false.
"""
@delegate add_model_param!(m::Model, name::Symbol,
                            value::Union{AbstractArray, AbstractRange, Tuple};
                            param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                            is_shared::Bool = false) => md
"""
    add_internal_param_conn(m::Model, conn::InternalParameterConnection)

Add internal parameter connection `conn` to model `m`.
"""
@delegate add_internal_param_conn!(m::Model, conn::InternalParameterConnection) => md

"""
    set_leftover_params!(m::Model, parameters::Dict)

Set all of the parameters in `Model` `m` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are strings (or convertible into Strings ie. Symbols) that 
match the names of unset parameters in the model, and all resulting new model 
parameters will be shared parameters.

Note that this function `set_leftover_params! has been deprecated, and uses should
be transitioned to using `update_leftover_params!` with keys specific to component-parameter 
pairs i.e. (comp_name, param_name) => value in the dictionary.
"""
@delegate set_leftover_params!(m::Model, parameters) => md

"""
    update_leftover_params!(m::Model, parameters::Dict)

Update all of the parameters in `Model` `m` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are Tuples of Symbols (or convertible to Symbols ie. Strings) 
of (comp_name, param_name) that match the component-parameter pair of 
unset parameters in the model.  All resulting connected model parameters will be 
unshared model parameters.
"""
@delegate update_leftover_params!(m::Model, parameters) => md


"""
    update_param!(m::Model, name::Symbol, value; update_timesteps = nothing)

Update the `value` of an model parameter in model `m`, referenced by
`name`. The update_timesteps keyword argument is deprecated, we keep it here 
just to provide warnings.
"""
@delegate update_param!(m::Model, name::Symbol, value; update_timesteps = nothing) => md

"""
    update_param!(m::Model, comp_name::Symbol, param_name::Symbol, value)

Update the `value` of the unshared model parameter in Model `m`'s Model Def connected
to component `comp_name`'s parameter `param_name`. 
"""
@delegate update_param!(m::Model, comp_name::Symbol, param_name::Symbol, value) => md

"""
    update_params!(m::Model, parameters::Dict; update_timesteps = nothing)

For each (k, v) in the provided `parameters` dictionary, `update_param!`
is called to update the model parameter identified by k to value v.

For updating unshared parameters, each key k must be a Tuple matching the name of a 
component in `obj` and the name of an parameter in that component.

For updating shared parameters, each key k must be a symbol or convert to a symbol 
matching the name of a shared model parameter that already exists in the model.
"""
@delegate update_params!(m::Model, parameters::Dict; update_timesteps = nothing) => md

"""
    add_comp!(
        m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        first::NothingInt=nothing,
        last::NothingInt=nothing,
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component indicated by `comp_id` to the model indicated by `m`. The component is added
at the end of the list unless one of the keywords `before` or `after` is specified. Note
that a copy of `comp_id` is made in the composite and assigned the give name. The optional
argument `rename` can be a list of pairs indicating `original_name => imported_name`. The optional 
arguments `first` and `last` indicate the times bounding the run period for the given component, 
which must be within the bounds of the model and if explicitly set are fixed.  These default 
to flexibly changing with the model's `:time` dimension.
"""
function add_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name; kwargs...)
    comp_def = add_comp!(m.md, comp_id, comp_name; kwargs...)
    return ComponentReference(m.md, comp_name)
end

"""
    add_comp!(
        m::Model, comp_def::AbstractComponentDef, comp_name::Symbol=comp_id.comp_name;
        first::NothingInt=nothing,
        last::NothingInt=nothing,
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component `comp_def` to the model indicated by `m`. The component is added at
the end of the list unless one of the keywords, `first`, `last`, `before`, `after`. Note
that a copy of `comp_id` is made in the composite and assigned the give name. The optional
argument `rename` can be a list of pairs indicating `original_name => imported_name`. The optional 
arguments `first` and `last` indicate the times bounding the run period for the given component, 
which must be within the bounds of the model and if explicitly set are fixed.  These default 
to flexibly changing with the model's `:time` dimension.
"""
function add_comp!(m::Model, comp_def::AbstractComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name; kwargs...)
    return add_comp!(m, comp_def.comp_id, comp_name; kwargs...)
end

"""
    replace!(
        m::Model,
        old_new::Pair{Symbol, ComponentDef},
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        reconnect::Bool=true
    )

For the pair `comp_name => comp_def` in `old_new`, replace the component with name `comp_name` in 
the model `m` with the new component specified by `comp_def`. The new component is added 
in the same position as the old component, unless one of the keywords `before` or `after` is 
specified for a different position. The optional boolean argument `reconnect` with default value 
`true` indicates whether the existing parameter connections should be maintained in the new 
component. Returns a ComponentReference for the added component.
"""
function Base.replace!(m::Model, old_new::Pair{Symbol, ComponentDef}; kwargs...)
    comp_name, comp_def = old_new
    _replace!(m.md, comp_name => comp_def.comp_id; kwargs...)
    return ComponentReference(m.md, comp_name)
end

@delegate ComponentReference(m::Model, name::Symbol) => md

"""
    components(m::Model)

Return an iterator on the components in a model's model instance.
"""
@delegate components(m::Model) => mi

@delegate compdefs(m::Model) => md

@delegate compdef(m::Model, comp_name::Symbol) => md

@delegate Base.length(m::Model) => md

@delegate first_and_step(m::Model) => md

@delegate time_labels(m::Model) => md

"""
    getspan(m::Model, comp_name::Symbol)

Return the number of timesteps a given component in a model will run for.
"""
@delegate getspan(m::Model, comp_name::Symbol) => md

"""
    datumdef(comp_def::ComponentDef, item::Symbol)

Return a DatumDef for `item` in the given component `comp_def`.
"""
function datumdef(comp_def::AbstractComponentDef, item::Symbol)
    if has_variable(comp_def, item)
        return variable(comp_def, item)

    elseif has_parameter(comp_def, item)
        return parameter(comp_def, item)
    else
        error("Cannot access data item; :$item is not a variable or a parameter in component $(comp_def.comp_id).")
    end
end

"""
    datumdef(m::Model, comp_name::Symbol, item::Symbol)

Return a DatumDef for `item` in the given component `comp_name` of model `m`.
"""
datumdef(m::Model, comp_name::Symbol, item::Symbol) = datumdef(compdef(m.md, comp_name), item)

"""
    dim_names(m::Model, comp_name::Symbol, datum_name::Symbol)

Return the dimension names for the variable or parameter `datum_name`
in the given component `comp_name` in model `m`.
"""
function dim_names(m::Model, comp_name::Symbol, datum_name::Symbol)
    # the line below would work if the comp_name is in the top level of components in m's component structure
    # return dim_names(compdef(m, comp_name), datum_name)
  
    paths = _get_all_paths(m)
    comp_path = paths[comp_name]
    comp_def = find_comp(m, comp_path)
    return dim_names(comp_def, datum_name)
end

dim_names(mm::MarginalModel, comp_name::Symbol, datum_name::Symbol) = dim_names(mm.base, comp_name, datum_name)

@delegate dimension(m::Model, dim_name::Symbol) => md

# Allow access of the form my_model[:grosseconomy, :tfp]
@delegate Base.getindex(m::Model, comp_name::Symbol, datum_name::Symbol) => mi

"""
    dim_count(m::Model, dim_name::Symbol)

Return the size of index `dim_name` in model `m`.
"""
@delegate dim_count(m::Model, dim_name::Symbol) => md
@delegate dim_counts(m::Model, dims::Vector{Symbol}) => md
@delegate dim_count_dict(m::Model) => md

"""
    dim_keys(m::Model, dim_name::Symbol)

Return keys for dimension `dim-name` in model `m`.
"""
@delegate dim_keys(m::Model, dim_name::Symbol) => md
"""
     dim_keys(mi::ModelInstance, dim_name::Symbol)

 Return keys for dimension `dim-name` in model instance `mi`.
 """
 @delegate dim_keys(mi::ModelInstance, dim_name::Symbol) => md
"""
    dim_key_dict(m::Model)

Return a dict of dimension keys for all dimensions in model `m`.
"""
@delegate dim_key_dict(m::Model) => md
"""
    dim_values(m::Model, name::Symbol)

Return values for dimension `name` in Model `m`.
"""
@delegate dim_values(m::Model, name::Symbol) => md
"""
    dim_value_dict(m::Model)

Return a dictionary of the values of all dimensions in Model `m`.
"""
@delegate dim_value_dict(m::Model) => md
"""
    set_dimension!(m::Model, name::Symbol, keys::Union{Vector, Tuple, AbstractRange})

Set the values of `m` dimension `name` to integers 1 through `count`, if `keys`` is
an integer; or to the values in the vector or range if `keys`` is either of those types.
"""
@delegate set_dimension!(m::Model, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange}) => md

@delegate check_parameter_dimensions(m::Model, value::AbstractArray, dims::Vector, name::Symbol) => md

@delegate parameter_names(m::Model, comp_name::Symbol) => md

@delegate parameter_dimensions(m::Model, comp_name::Symbol, param_name::Symbol) => md

@delegate parameter_unit(m::Model, comp_name::Symbol, param_name::Symbol) => md

parameter(m::Model, comp_def::ComponentDef, param_name::Symbol) = parameter(comp_def, param_name)

parameter(m::Model, comp_name::Symbol, param_name::Symbol) = parameter(m, compdef(m, comp_name), param_name)

"""
    parameters(m::Model, comp_name::Symbol)

Return a list of the parameter definitions for `comp_name` in model `m`.
"""
parameters(m::Model, comp_name::Symbol) = parameters(compdef(m, comp_name))

variable(m::Model, comp_name::Symbol, var_name::Symbol) = variable(compdef(m, comp_name), var_name)

@delegate variable_unit(m::Model, comp_path::ComponentPath, var_name::Symbol) => md

@delegate variable_dimensions(m::Model, comp_path::ComponentPath, var_name::Symbol) => md
@delegate variable_dimensions(m::Model, comp::Symbol, var_name::Symbol) => md
@delegate variable_dimensions(m::Model, comp_path::NTuple{N, Symbol} where N, var_name::Symbol) => md

"""
    variables(m::Model, comp_name::Symbol)

Return an iterator on the variable definitions for `comp_name` in model `m`.
"""
variables(m::Model, comp_name::Symbol) = variables(compdef(m, comp_name))

@delegate variable_names(m::Model, comp_name::Symbol) => md

"""
    add_shared_param!(m::Model, name::Symbol, value::Any; dims::Array{Symbol}=Symbol[], datatype::DataType=Nothing)

User-facing API function to add a shared parameter to Model `m` with name
`name` and value `value`, and an array of dimension names `dims` which dfaults to 
an empty vector.  The `is_shared` attribute of the added Model Parameter will be `true`.

The `value` can by a scalar, an array, or a NamedAray. Optional keyword argument 'dims' is a list
of the dimension names of the provided data, and will be used to check that they match the
model's index labels.  This must be included if the `value` is not a scalar, and defaults
to an empty vector. Optional keyword argument `datatype` allows user to specify a datatype
to use for the shared model parameter.
"""
@delegate add_shared_param!(m::Model, name::Symbol, value::Any; dims::Array{Symbol}=Symbol[], data_type::DataType=Nothing) => md
                    
"""
    add_model_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims)

Add a one or two dimensional (optionally, time-indexed) array parameter `name`
with value `value` to the model `m`.
"""
@delegate add_model_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims) => md

"""
    add_model_scalar_param!(m::Model, name::Symbol, value::Any)

Add a scalar type parameter `name` with value `value` to the model `m`.
"""
@delegate add_model_scalar_param!(m::Model, name::Symbol, value::Any) => md

"""
    delete!(m::Model, component::Symbol; deep::Bool=false)

Delete a `component` by name from a model `m`'s ModelDef, and nullify the ModelInstance.
If `deep=true` then any model model parameters connected only to 
this component will also be deleted.
"""
@delegate Base.delete!(m::Model, comp_name::Symbol; deep::Bool=false) => md

"""
    delete_param!(m::Model, model_param_name::Symbol)

Delete `model_param_name` from a model `m`'s ModelDef's list of model parameters, and
also remove all external parameters connections that were connected to `model_param_name`.
"""
@delegate delete_param!(m::Model, model_param_name::Symbol) => md

"""
    set_param!(m::Model, comp_name::Symbol, param_name::Symbol, value; dims=nothing)

Set the parameter of a component `comp_name` in a model `m` to a given `value`.
The `value` can by a scalar, an array, or a NamedAray. Optional keyword argument 'dims'
is a list of the dimension names of the provided data, and will be used to check
that they match the model's index labels.
"""
@delegate set_param!(m::Model, comp_name::Symbol, param_name::Symbol, value; dims=nothing) => md

"""
    set_param!(m::Model, comp_name::Symbol, param_name::Symbol, model_param_name::Symbol, value; dims=nothing)

Set the parameter `param_name` of a component `comp_name` in a model `m` to a given `value`, 
storing the value in the model's parameter list by the provided name `model_param_name`.
The `value` can by a scalar, an array, or a NamedAray. Optional keyword argument 'dims'
is a list of the dimension names of the provided data, and will be used to check
that they match the model's index labels.
"""
@delegate set_param!(m::Model, comp_name::Symbol, param_name::Symbol, model_param_name::Symbol, value; dims=nothing) => md


"""
    set_param!(m::Model, param_name::Symbol, value; dims=nothing)

Set the value of a parameter in all components of the model that have a parameter of 
the specified name.
"""
@delegate set_param!(m::Model, param_name::Symbol, value; dims=nothing, ignoreunits::Bool=false) => md

@delegate import_params!(m::Model) => md

"""
    Base.run(m::Model; ntimesteps::Int=typemax(Int), rebuild::Bool=false,
            dim_keys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)

Run model `m` once.
"""
function Base.run(m::Model; ntimesteps::Int=typemax(Int), rebuild::Bool=false,
                  dim_keys::Union{Nothing, Dict{Symbol, Vector{T} where T <: DimensionKeyTypes}}=nothing)
    if length(m) == 0
        error("Cannot run a model with no components.")
    end

    if (rebuild || ! is_built(m))
        build!(m)
    end

    # println("Running model...")
    mi = modelinstance(m)
    run(mi, ntimesteps, dim_keys)
    nothing
end

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

# -- throw errors -- 

"""
    replace_comp!(
        m::Model, comp_def::ComponentDef, comp_name::Symbol=comp_id.comp_name;
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        reconnect::Bool=true
    )

Deprecated function for replacing the component with name `comp_name` in model `m` with the 
new component specified by `comp_def`. Use the following syntax instead:

`replace!(m, comp_name => comp_def; kwargs...)`

See docstring for `replace!` for further description of available functionality.
"""
function replace_comp!(m::Model, comp_def::ComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name; kwargs...)
    error("Function `replace_comp!(m, comp_def, comp_name; kwargs...)` has been deprecated. Use `replace!(m, comp_name => comp_def; kwargs...)` instead.")
end

"""
    replace_comp!(
        m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        reconnect::Bool=true
    )

Deprecated function for replacing the component with name `comp_name` in model `m` with the 
new component specified by `comp_id`. Use the following syntax instead:

`replace!(m, comp_name => Mimi.compdef(comp_id); kwargs...)`

See docstring for `replace!` for further description of available functionality.
"""
function replace_comp!(m::Model, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name; kwargs...)
    error("Function `replace_comp!(m, comp_id, comp_name; kwargs...)` has been deprecated. Use `replace!(m, comp_name => Mimi.compdef(comp_id); kwargs...)` instead.")
end

# -- throw warnings --

@delegate set_external_param!(m::Model, name::Symbol,
                              value::Union{Number, AbstractArray, AbstractRange, Tuple};
                              param_dims::Union{Nothing,Array{Symbol}} = nothing) => md

@delegate set_external_param!(m::Model, name::Symbol, value::ModelParameter) => md
@delegate set_external_array_param!(m::Model, name::Symbol, value::Union{AbstractArray, TimestepArray}, dims) => md
@delegate set_external_scalar_param!(m::Model, name::Symbol, value::Any) => md
@delegate external_params(m::Model) => md
@delegate external_param(m::Model, name::Symbol; missing_ok=false) => md
