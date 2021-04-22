Base.length(obj::AbstractComponentDef) = 0   # no sub-components
Base.length(obj::AbstractCompositeComponentDef) = length(components(obj))

function compdef(comp_id::ComponentId)
    # @info "compdef: mod=$(comp_id.module_obj) name=$(comp_id.comp_name)"
    return getfield(comp_id.module_obj, comp_id.comp_name)
end

compdef(cr::ComponentReference) = find_comp(cr)

compdef(obj::AbstractCompositeComponentDef, path::ComponentPath) = find_comp(obj, path)

compdef(obj::AbstractCompositeComponentDef, comp_name::Symbol) = components(obj)[comp_name]

has_comp(obj::AbstractCompositeComponentDef, comp_name::Symbol) = haskey(components(obj), comp_name)
compdefs(obj::AbstractCompositeComponentDef) = values(components(obj))
compkeys(obj::AbstractCompositeComponentDef) = keys(components(obj))

# Allows method to be called harmlessly on leaf component defs, which simplifies recursive funcs.
compdefs(c::ComponentDef) = []

compmodule(comp_id::ComponentId) = comp_id.module_obj
compname(comp_id::ComponentId)   = comp_id.comp_name

compmodule(obj::AbstractComponentDef) = compmodule(obj.comp_id)
compname(obj::AbstractComponentDef)   = compname(obj.comp_id)

compnames() = map(compname, compdefs())

dirty(md::ModelDef) = md.dirty

function dirty!(obj::AbstractComponentDef)
    root = get_root(obj)
    if root === nothing
        return
    end

    if root isa ModelDef
        dirty!(root)
    end
end

dirty!(md::ModelDef) = (md.dirty = true)

number_type(md::ModelDef) = md.number_type

function number_type(obj::AbstractCompositeComponentDef)
    root = get_root(obj)
    # TBD: hack alert. Need to allow number_type to be specified
    # for composites that are not yet connected to a ModelDef?
    return root isa ModelDef ? root.number_type : Float64
end

first_period(root::AbstractCompositeComponentDef, comp::AbstractComponentDef) = @or(first_period(comp), first_period(root))
last_period(root::AbstractCompositeComponentDef,  comp::AbstractComponentDef) = @or(last_period(comp),  last_period(root))

find_first_period(comp_def::AbstractComponentDef) = @or(first_period(comp_def), first_period(get_root(comp_def)))
find_last_period(comp_def::AbstractComponentDef) = @or(last_period(comp_def), last_period(get_root(comp_def)))

"""
    delete!(md::ModelDef, comp_name::Symbol; deep::Bool=false)

Delete a `component` by name from `md`.
If `deep=true` then any external model parameters connected only to 
this component will also be deleted.
"""
function Base.delete!(md::ModelDef, comp_name::Symbol; deep::Bool=false)
    if ! has_comp(md, comp_name)
        error("Cannot delete '$comp_name': component does not exist.")
    end

    comp_def = compdef(md, comp_name)
    delete!(md.namespace, comp_name)

    # Remove references to the deleted comp
    comp_path = comp_def.comp_path

    # Remove internal parameter connections 
    ipc_filter = x -> x.src_comp_path != comp_path && x.dst_comp_path != comp_path
    filter!(ipc_filter, md.internal_param_conns)

    # Remove external parameter connections

    if deep # Find and delete external_params that were connected only to the deleted component if specified
        # Get all external parameters this component is connected to
        comp_ext_params = map(x -> x.external_param, filter(x -> x.comp_path == comp_path, md.external_param_conns))

        # Identify which ones are not connected to any other components
        unbound_filter = x -> length(filter(epc -> epc.external_param == x, md.external_param_conns)) == 1
        unbound_comp_params = filter(unbound_filter, comp_ext_params)

        # Delete these parameters
        [delete_param!(md, param_name) for param_name in unbound_comp_params]
    end        

    # delete any external connections for this component
    epc_filter = x -> x.comp_path != comp_path
    filter!(epc_filter, md.external_param_conns)

    dirty!(md)
end

"""
    delete_param!(md::ModelDef, external_param_name::Symbol)

Delete `external_param_name` from `md`'s list of external parameters, and also 
remove all external parameters connections that were connected to `external_param_name`.
"""
function delete_param!(md::ModelDef, external_param_name::Symbol)
    if external_param_name in keys(md.external_params)
        delete!(md.external_params, external_param_name)
    else
        error("Cannot delete $external_param_name, not found in external parameter list.")
    end
    
    # Remove external parameter connections
    epc_filter = x -> x.external_param != external_param_name
    filter!(epc_filter, md.external_param_conns)

    dirty!(md)
end

@delegate Base.haskey(comp::AbstractComponentDef, key::Symbol) => namespace

Base.getindex(comp::AbstractComponentDef, key::Symbol) = comp.namespace[key]

#
# Component namespaces
#
"""
    istype(T::DataType)

Return an anonymous func that can be used to filter a dict by data type of values.
Example: `filter(istype(AbstractComponentDef), obj.namespace)`
"""
istype(T::DataType) = (pair -> pair.second isa T)

# Namespace filter functions return dicts of values for the given type.
# N.B. only composites hold other comps in the namespace.
components(model::Model, comp_name::Symbol) = components(compdef(model, comp_name))
components(obj::AbstractComponentDef) = filter(istype(AbstractComponentDef), obj.namespace)

param_dict(obj::ComponentDef) = filter(istype(ParameterDef), obj.namespace)
param_dict(obj::AbstractCompositeComponentDef) = filter(istype(CompositeParameterDef), obj.namespace)

var_dict(obj::ComponentDef) = filter(istype(VariableDef), obj.namespace)
var_dict(obj::AbstractCompositeComponentDef) = filter(istype(CompositeVariableDef), obj.namespace)

"""
    parameters(comp_def::AbstractComponentDef)

Return an iterator of the parameter definitions (or references) for `comp_def`.
"""
parameters(obj::AbstractComponentDef) = values(param_dict(obj))

parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

"""
    variables(comp_def::AbstractComponentDef)

Return an iterator of the variable definitions (or references) for `comp_def`.
"""
variables(obj::ComponentDef)  = values(filter(istype(VariableDef), obj.namespace))

variables(obj::AbstractCompositeComponentDef) = values(filter(istype(CompositeVariableDef), obj.namespace))

variables(comp_id::ComponentId)  = variables(compdef(comp_id))

"""
Return true if the component namespace has an item `name` that isa `T`
"""
function _ns_has(comp_def::AbstractComponentDef, name::Symbol, T::DataType)
    return haskey(comp_def.namespace, name) && comp_def.namespace[name] isa T
end

"""
Get a named element from the namespace of `obj` and verify its type.
"""
function _ns_get(obj::AbstractComponentDef, name::Symbol, T::DataType)
    if ! haskey(obj.namespace, name)
        error("Item :$name was not found in component $(obj.comp_path)")
    end
    item = obj[name]
    item isa T || error(":$name in component $(obj.comp_path) is a $(typeof(item)); expected type $T")
    return item
end

"""
Save a value to a component's namespace. Allow replacement of existing values for a key
only with items of the same type; otherwise an error is thrown.
"""
function _save_to_namespace(comp::AbstractComponentDef, key::Symbol, value::NamespaceElement)
    if haskey(comp, key)
        elt_type = typeof(comp[key])
        T = typeof(value)
        elt_type == T || error("Cannot replace item $key, type $elt_type, with object type $T in component $(comp.comp_path).")
    end

    comp.namespace[key] = value
end

function Base.setindex!(comp::AbstractCompositeComponentDef, value::CompositeNamespaceElement, key::Symbol)
    _save_to_namespace(comp, key, value)
end

# Leaf components store DatumDef instances in the namespace
function Base.setindex!(comp::ComponentDef, value::LeafNamespaceElement, key::Symbol)
    _save_to_namespace(comp, key, value)
end

#
# Dimensions
#

step_size(values::Vector{Int}) = (length(values) > 1 ? values[2] - values[1] : 1)

#
# TBD: should these be defined as methods of CompositeComponentDef, i.e., not for leaf comps
#
function step_size(obj::AbstractComponentDef)
    keys = time_labels(obj)
    return step_size(keys)
end

function first_and_step(obj::AbstractComponentDef)
    keys = time_labels(obj)
    return first_and_step(keys)
end

first_and_step(values::Vector{Int}) = (values[1], step_size(values))

first_and_last(obj::AbstractComponentDef) = (obj.first, obj.last)

time_labels(obj::AbstractComponentDef) = dim_keys(obj, :time)

function check_parameter_dimensions(md::ModelDef, value::AbstractArray, dims::Vector, name::Symbol)
    for dim in dims
        if has_dim(md, dim)
            if isa(value, NamedArray)
                labels = names(value, findnext(isequal(dim), dims, 1))
                dim_vals = dim_keys(md, dim)
                for i in 1:length(labels)
                    if labels[i] != dim_vals[i]
                        error("Labels for dimension $dim in parameter $name do not match model's index values")
                    end
                end
            end
        else
            error("Dimension $dim in parameter $name not found in model's dimensions")
        end
    end
end

# we now require the backup data to have the same dimensions as the model, regardless
# of the time span of the specific component
function datum_size(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, datum_name::Symbol)
    dims = dim_names(comp_def, datum_name)
    datum_size = (dim_counts(obj, dims)...,)
    return datum_size
end

# helper functions used to determine if the provided time values are
# a uniform range.

all_equal(values) = all(map(val -> val == values[1], values[2:end]))

isuniform(values) = (length(values) == 0 ? false : all_equal(diff(collect(values))))

# needed when time dimension is defined using a single integer
isuniform(values::Int) = true

#
# Parameters
#

# Callable on both ParameterDef and VariableDef
dim_names(obj::AbstractDatumDef) = obj.dim_names

"""
    parameter_names(md::ModelDef, comp_name::Symbol)

Return a list of all parameter names for a given component `comp_name` in a model def `md`.
"""
parameter_names(md::ModelDef, comp_name::Symbol) = parameter_names(compdef(md, comp_name))

parameter_names(comp_def::AbstractComponentDef) = collect(keys(param_dict(comp_def)))

parameter(obj::AbstractComponentDef, name::Symbol) = _ns_get(obj, name, AbstractParameterDef)

parameter(obj::AbstractCompositeComponentDef, comp_name::Symbol,
          param_name::Symbol) = parameter(compdef(obj, comp_name), param_name)

has_parameter(comp_def::AbstractComponentDef, name::Symbol) = _ns_has(comp_def, name, AbstractParameterDef)
has_parameter(md::ModelDef, name::Symbol) = haskey(md.external_params, name)

function parameter_unit(obj::AbstractComponentDef, param_name::Symbol)
    param = parameter(obj, param_name)
    return unit(param)
end

"""
    parameter_dimensions(obj::AbstractComponentDef, param_name::Symbol)

Return the names of the dimensions of parameter `param_name` exposed in the component
definition indicated by `obj`.
"""
function parameter_dimensions(obj::AbstractComponentDef, param_name::Symbol)
    param = parameter(obj, param_name)
    return dim_names(param)
end

function parameter_unit(obj::AbstractComponentDef, comp_name::Symbol, param_name::Symbol)
    return parameter_unit(compdef(obj, comp_name), param_name)
end

"""
    parameter_dimensions(obj::AbstractComponentDef, comp_name::Symbol, param_name::Symbol)

Return the names of the dimensions of parameter `param_name` in component `comp_name`,
which is exposed in composite component definition indicated by`obj`.
"""
function parameter_dimensions(obj::AbstractComponentDef, comp_name::Symbol, param_name::Symbol)
    return parameter_dimensions(compdef(obj, comp_name), param_name)
end


"""
Find and return a vector of tuples containing references to a ComponentDef and
a ParameterDef for all instances of parameters with name `param_name`, below the
composite `obj`. If none are found, an empty vector is returned.
"""
function find_params(obj::AbstractCompositeComponentDef, param_name::Symbol)
    found = Vector{Tuple{ComponentDef, ParameterDef}}()

    for (name, compdef) in components(obj)
        items = find_params(compdef, param_name)
        append!(found, items)
    end

    return found
end

function find_params(obj::ComponentDef, param_name::Symbol)
    namespace = ns(obj)
    if haskey(namespace, param_name) && (item = namespace[param_name]) isa ParameterDef
        return [(obj, item)]
    end

    return []
end

"""
    recurse(obj::AbstractComponentDef, f::Function, args...;
            composite_only=false, depth_first=true)

Generalized recursion functions for walking composite structures. The function `f`
is called with the first argument a leaf or composite component, followed by any
other arguments passed before the semi-colon delimiting keywords. Set `composite_only`
to `true` if the function should be called only on composites, or `leaf_only` to
call `f` only on leaf ComponentDefs.

By default, the recursion is depth-first; set `depth_first=false`, to walk the
structure breadth-first.

For example, to collect all parameters defined in leaf ComponentDefs, do this:

    `params = []
     recurse(md, obj->append!(params, parameters(obj)); leaf_only=true)`
"""
function recurse(obj::AbstractCompositeComponentDef, f::Function, args...;
                 composite_only=false, leaf_only=false, depth_first=true)

    if (! leaf_only && ! depth_first)
        f(obj, args...)
    end

    for child in compdefs(obj)
        recurse(child, f, args...;
                composite_only=composite_only, leaf_only=leaf_only,
                depth_first=depth_first)
    end

    if (! leaf_only && depth_first)
        f(obj, args...)
    end

    nothing
end

# Same thing, but for leaf ComponentDefs
function recurse(obj::ComponentDef, f::Function, args...;
    composite_only=false, leaf_only=false, depth_first=true)

    composite_only || f(obj, args...)
    nothing
end

# return UnnamedReference's for all subcomponents' parameters
function subcomp_params(obj::AbstractCompositeComponentDef)
    params = UnnamedReference[]
    for (name, sub_obj) in obj.namespace
        if sub_obj isa AbstractComponentDef
            for (subname, curr_obj) in sub_obj.namespace
                if curr_obj isa AbstractParameterDef
                    push!(params, UnnamedReference(name, subname))
                end
            end
        end
    end
    return params
end

"""
    set_param!(md::ModelDef, comp_name::Symbol,
               value_dict::Dict{Symbol, Any}, param_names)

Call `set_param!()` for each name in `param_names`, retrieving the corresponding value from
`value_dict[param_name]`.
"""
function set_param!(md::ModelDef, comp_name::Symbol, value_dict::Dict{Symbol, Any}, param_names)
    for param_name in param_names
        set_param!(md, comp_name, value_dict, param_name)
    end
end

function set_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, value; dims=nothing)
    set_param!(md, comp_name, param_name, param_name, value, dims=dims)
end

function set_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol, value; dims=nothing)
    comp_def = compdef(md, comp_name)
    @or(comp_def, error("Top-level component with name $comp_name not found"))
    set_param!(md, comp_def, param_name, ext_param_name, value, dims=dims)
end

function set_param!(md::ModelDef, comp_def::AbstractComponentDef, param_name::Symbol, ext_param_name::Symbol, value; dims=nothing)
    has_parameter(comp_def, param_name) ||
        error("Cannot find parameter :$param_name in component $(pathof(comp_def))")

    if has_parameter(md, ext_param_name)
        error("Cannot set parameter :$ext_param_name, the model already has an external parameter with this name.", 
        " Use `update_param!(m, param_name, value)` to change the value, or use ",
        "`set_param!(m, comp_name, param_name, unique_param_name, value)` to set a value for only this component.")
    end

    set_param!(md, param_name, value, dims = dims, comps = [comp_def], ext_param_name = ext_param_name)
end

"""
    set_param!(md::ModelDef, param_name::Symbol, value; dims=nothing)

Set the value of a parameter in all components of the model that have a parameter of 
the specified name.

The `value` can by a scalar, an array, or a NamedAray. Optional keyword argument 'dims' is a list
of the dimension names of the provided data, and will be used to check that they match the
model's index labels.
"""
function set_param!(md::ModelDef, param_name::Symbol, value; dims=nothing, ignoreunits::Bool=false, comps=nothing, ext_param_name=nothing)
    # search immediate subcomponents for this parameter
    if comps === nothing
        comps = [comp for (compname, comp) in components(md) if has_parameter(comp, param_name)]
    end

    if ext_param_name === nothing
        ext_param_name = param_name
    end

    if isempty(comps)
        error("Cannot set parameter :$param_name; not found in ModelDef or children")
    end

    # which fields to check for collisions in subcomponents
    fields = ignoreunits ? (:dim_names, :datatype) : (:dim_names, :datatype, :unit)
    collisions = _find_collisions(fields, [comp => param_name for comp in comps])
    if ! isempty(collisions) 
        if :unit in collisions
            error("Cannot set parameter :$param_name in the model, components have conflicting values for the :unit field of this parameter. ", 
            "Call `set_param!` with optional keyword argument `ignoreunits = true` to override.")
        else
            spec = join(collisions, " and ")
            error("Cannot set parameter :$param_name in the model, components have conflicting values for the $spec of this parameter. ",
            "Set these parameters with separate calls to `set_param!(m, comp_name, param_name, unique_param_name, value)`.")
        end
    end

    if value isa NamedArray
        dims = dimnames(value)
    end

    if dims !== nothing
        check_parameter_dimensions(md, value, dims, param_name)
    end

    comp_def = comps[1]   # since we alread checked that the found comps have no conflicting fields in their parameter definitions, we can just use the first one for reference below
    param_def = comp_def[param_name]
    param_dims = param_def.dim_names
    num_dims = length(param_dims)

    data_type = param_def.datatype
    dtype = Union{Missing, (data_type == Number ? number_type(md) : data_type)}

    if num_dims > 0

        # convert the number type and, if NamedArray, convert to Array
        if dtype <: AbstractArray
            value = convert(dtype, value)
        else
            # check that number of dimensions matches
            value_dims = length(size(value))
            if num_dims != value_dims
                error("Mismatched data size for a set parameter call: dimension :$param_name",
                      " in has $num_dims dimensions; indicated value",
                      " has $value_dims dimensions.")
            end
            value = convert(Array{dtype, num_dims}, value)
        end

        ti = get_time_index_position(param_dims)

        if ti !== nothing   # there is a time dimension
            T = eltype(value)

            if num_dims == 0
                values = value
            else

                # Use the first from the Model def, not the component, since we now say that the
                # data needs to match the dimensions of the model itself, so we need to allocate
                # the full time length even if we pad it with missings.
                first = first_period(md)
                first === nothing && @warn "set_param!: first === nothing"

                last = last_period(md)
                last === nothing && @warn "set_param!: last === nothing"

                if isuniform(md)
                    stepsize = step_size(md)
                    values = TimestepArray{FixedTimestep{first, stepsize, last}, T, num_dims, ti}(value)
                else
                    times = time_labels(md)
                    first_index = findfirst(isequal(first), times)
                    values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, num_dims, ti}(value)
                end
            end
        else
            values = value
        end

        param = ArrayModelParameter(values, param_dims)
        # Need to check the dimensions of the parameter data against each component before addeding it to the model's external parameters
        for comp in comps
            _check_labels(md, comp, param_name, param)
        end
        set_external_param!(md, ext_param_name, param)


    else # scalar parameter case
        value = convert(dtype, value)
        set_external_scalar_param!(md, ext_param_name, value)
    end

    # connect_param! calls dirty! so we don't have to
    for comp in comps
        # Set check_labels=false because we already checked above before setting the param
        connect_param!(md, comp, param_name, ext_param_name, check_labels=false)
    end
    nothing
end

#
# Variables
#
variable(obj::ComponentDef, name::Symbol) = _ns_get(obj, name, VariableDef)

variable(obj::AbstractCompositeComponentDef, name::Symbol) = _ns_get(obj, name, CompositeVariableDef)

variable(comp_id::ComponentId, var_name::Symbol) = variable(compdef(comp_id), var_name)

variable(obj::AbstractCompositeComponentDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(obj, comp_name), var_name)

function variable(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    comp_def = find_comp(obj, comp_path)
    return variable(comp_def, var_name)
end

has_variable(comp_def::ComponentDef, name::Symbol) = _ns_has(comp_def, name, VariableDef)

has_variable(comp_def::AbstractCompositeComponentDef, name::Symbol) = _ns_has(comp_def, name, CompositeVariableDef)

"""
    variable_names(md::AbstractCompositeComponentDef, comp_name::Symbol)

Return a list of all variable names for a given component `comp_name` in a model def `md`.
"""
variable_names(obj::AbstractCompositeComponentDef, comp_name::Symbol) = variable_names(compdef(obj, comp_name))

variable_names(comp_def::AbstractComponentDef) = [nameof(var) for var in variables(comp_def)]


function variable_unit(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    var = variable(obj, comp_path, var_name)
    return unit(var)
end

function variable_unit(obj::AbstractComponentDef, name::Symbol)
    var = variable(obj, name)
    return unit(var)
end

unit(obj::AbstractDatumDef) = obj.unit

"""
    variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)

Return the names of the dimensions of variable `var_name` exposed in the composite
component definition indicated by`obj` along the component path `comp_path`. The
`comp_path` is of type `Mimi.ComponentPath` with the single field being an NTuple
of symbols describing the relative (to a composite) or absolute (relative to ModelDef)
path through composite nodes to specific composite or leaf node.
"""
function variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    var = variable(obj, comp_path, var_name)
    return dim_names(var)
end

"""
    variable_dimensions(obj::AbstractCompositeComponentDef, comp::Symbol, var_name::Symbol)

Return the names of the dimensions of variable `var_name` exposed in the composite
component definition indicated by `obj` for the component `comp`, which exists in a
flat model.
"""
function variable_dimensions(obj::AbstractCompositeComponentDef, comp::Symbol, var_name::Symbol)
    return variable_dimensions(obj, Mimi.ComponentPath((comp,)), var_name)
end

"""
    variable_dimensions(obj::AbstractCompositeComponentDef, comp::Symbol, var_name::Symbol)

Return the names of the dimensions of variable `var_name` exposed in the composite
component definition indicated by `obj` along the component path `comp_path`. The
`comp_path` is a tuple of symbols describing the relative (to a composite) or
absolute (relative to ModelDef) path through composite nodes to specific composite or leaf node.
"""
function variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::NTuple{N, Symbol}, var_name::Symbol) where N
    return variable_dimensions(obj, Mimi.ComponentPath((comp_path)), var_name)
end

"""
    variable_dimensions(obj::AbstractComponentDef, name::Symbol)

Return the names of the dimensions of variable `name` exposed in the component definition
indicated by `obj`.
"""
function variable_dimensions(obj::AbstractComponentDef, name::Symbol)
    var = variable(obj, name)
    return dim_names(var)
end

#
# Other
#

# Return the number of timesteps a given component in a model will run for.
function getspan(obj::AbstractComponentDef, comp_name::Symbol)
    comp_def = compdef(obj, comp_name)
    return getspan(obj, comp_def)
end

function getspan(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef)
    first = first_period(obj, comp_def)
    last  = last_period(obj, comp_def)
    times = time_labels(obj)
    first_index = findfirst(isequal(first), times)
    last_index  = findfirst(isequal(last), times)
    return size(times[first_index:last_index])
end

#
# Model
#

function _add_anonymous_dims!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef)
    for (name, dim) in filter(pair -> pair[2] !== nothing, comp_def.dim_dict)
        # @info "Setting dimension $name to $dim"
        set_dimension!(obj, name, dim)
    end
end

function _set_comps!(obj::AbstractCompositeComponentDef, comps::OrderedDict{Symbol, AbstractComponentDef})
    for key in keys(components(obj))
        delete!(obj.namespace, key)     # delete only from namespace, keeping connections
    end

    # add comps to namespace
    for (key, value) in comps
        obj[key] = value
    end

    dirty!(obj)
end

# Save a back-pointer to the container object and set the comp_path
function parent!(child::AbstractComponentDef, parent::AbstractCompositeComponentDef)
    child.parent = parent
    child.comp_path = ComponentPath(parent, child.name)
    nothing
end

# Recursively ascend the component tree structure to find the root node
get_root(node::AbstractComponentDef) = (node.parent === nothing ? node : get_root(node.parent))

const NothingInt      = Union{Nothing, Int}
const NothingSymbol   = Union{Nothing, Symbol}
const NothingPairList = Union{Nothing, Vector{Pair{Symbol, Symbol}}}

function _insert_comp!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef;
                       before::NothingSymbol=nothing, after::NothingSymbol=nothing)

    comp_name = nameof(comp_def)

    if before === nothing && after === nothing
        obj[comp_name] = comp_def   # add to namespace
    else
        new_comps = OrderedDict{Symbol, AbstractComponentDef}()

        if before !== nothing
            if ! has_comp(obj, before)
                error("Component to add before ($before) does not exist")
            end

            for (k, v) in components(obj)
                if k == before
                    new_comps[comp_name] = comp_def
                end
                new_comps[k] = v
            end

        else    # after !== nothing, since we've handled all other possibilities above
            if ! has_comp(obj, after)
                error("Component to add before ($before) does not exist")
            end

            for (k, v) in components(obj)
                new_comps[k] = v
                if k == after
                    new_comps[comp_name] = comp_def
                end
            end
        end

        _set_comps!(obj, new_comps)
    end

    # adjust paths to include new parent
    # @info "_insert_comp: fixing comp path"
    _fix_comp_path!(comp_def, obj)

    # @info "parent obj comp_path: $(printable(obj.comp_path))"
    # @info "inserted comp's path: $(comp_def.comp_path)"
    dirty!(obj)

    nothing
end

"""
    _propagate_first_last!(obj::AbstractComponentDef; first::NothingInt=nothing, last::NothingInt=nothing)

Propagate first and/or last through a component def tree. This function will override
any first and last that have been previously set. 
"""
function _propagate_first_last!(obj::AbstractComponentDef; first::NothingInt=nothing, last::NothingInt=nothing)
        
    !isnothing(first) ? obj.first = first : nothing
    !isnothing(last) ? obj.last = last : nothing

    for c in compdefs(obj)  # N.B. compdefs returns empty list for leaf nodes     
        _propagate_first_last!(c, first=first, last=last)
    end
end

"""
    _propagate_time_dim!(obj::AbstractComponentDef, t::Dimension)

Propagate a time dimension down through the comp def tree. If first and last 
keyword arguments are not set in a given comp def they will be set to match the
time dimension. 
"""
function _propagate_time_dim!(obj::AbstractComponentDef, t::Dimension)
    
    set_dimension!(obj, :time, t)

    t_first = firstindex(t)
    t_last = lastindex(t)
    
    curr_first = obj.first
    curr_last = obj.last

    # Handle First
    if isnothing(curr_first) || isa(obj, Mimi.ModelDef) # if we are working with an unset attribute or a ModelDef we always want to set first
        obj.first = t_first
    elseif t_first > curr_first # working with a component so we only want to move it if we're moving first forward (currently unreachable b/c error caught above)
        obj.first = t_first
    end

    # Handle Last
    if isnothing(curr_last) || isa(obj, Mimi.ModelDef)
        obj.last = t_last
    elseif t_last < curr_last  # working with a component so we only want to move it if we're moving last back (currently unreachable b/c caught error above)
        obj.last = t_last
    end

    for c in compdefs(obj)      # N.B. compdefs returns empty list for leaf nodes
        _propagate_time_dim!(c, t)
    end

    # run over the object and check that first and last are within the time
    # dimension of the parent
    _check_times(obj, [keys(t)...])
end

"""
function _check_times(obj::AbstractComponentDef, parent_time_keys::Array)

    Check that all first and last times exist within contained within a comp_def
    `obj`'s parent time keys `parent_time_keys`.
"""
function _check_times(obj::AbstractComponentDef, parent_time_keys::Array)
    
    first_index = findfirst(isequal(obj.first), parent_time_keys)
    isnothing(first_index) ? error("The first index ($(obj.first)) of component $(nameof(obj)) must exist within its model's time dimension $parent_time_keys.") : nothing

    last_index = findfirst(isequal(obj.last), parent_time_keys)
    isnothing(last_index) ? error("The last index ($(obj.last)) of component $(nameof(obj)) must exist within its model's time dimension $parent_time_keys.") : nothing

    for c in compdefs(obj)      # N.B. compdefs returns empty list for leaf nodes
        _check_times(c, parent_time_keys[first_index:last_index])
    end

end

"""
function _check_first_last(obj::Union{Model, ModelDef}; first::NothingInt = nothing, last::NothingInt = nothing)

    Check that all first and last times are properly contained within a comp_def
    `obj`'s time labels.
"""
function _check_first_last(obj::Union{Model, ModelDef}; first::NothingInt = nothing, last::NothingInt = nothing)
    times = time_labels(obj)
    !isnothing(first) && !(first in times) && error("The first index ($first) must exist within the model's time dimension $times.")
    !isnothing(last) && !(last in times) && error("The last index ($last) must exist within the model's time dimension $times")
end

"""
     function set_first_last!(obj::AbstractCompositeComponentDef, comp_name::Symbol; first::NothingInt=nothing, last::NothingInt=nothing)

 Set the `first` and/or `last` attributes of model `obj`'s component `comp_name`, 
 after it has been added to the model.  This will propagate the `first` and `last`
 through any subcomponents of `comp_name` as well.  Note that this will override 
 any previous `first` and `last` settings. 
 """
 function set_first_last!(obj::Model, comp_name::Symbol; first::NothingInt=nothing, last::NothingInt=nothing)
    !has_comp(obj, comp_name) && error("Model does not contain a component named $comp_name")
    
    _check_first_last(obj, first = first, last = last)

    comp_def = compdef(obj, comp_name)
    _propagate_first_last!(comp_def, first=first, last=last)

    dirty!(comp_def)
end

"""
    add_comp!(
        obj::AbstractCompositeComponentDef,
        comp_def::AbstractComponentDef,
        comp_name::Symbol=comp_def.comp_id.comp_name;
        first::NothingInt=nothing,
        last::NothingInt=nothing,
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component `comp_def` to the composite component indicated by `obj`. The component is
added at the end of the list unless one of the keywords `before` or `after` is specified.
Note that a copy of `comp_id` is made in the composite and assigned the give name. The optional
argument `rename` can be a list of pairs indicating `original_name => imported_name`. The optional 
arguments `first` and `last` indicate the times bounding the run period for the given component, 
which must be within the bounds of the model and if explicitly set are fixed.  These default 
to flexibly changing with the model's `:time` dimension.
"""
function add_comp!(obj::AbstractCompositeComponentDef,
                   comp_def::AbstractComponentDef,
                   comp_name::Symbol=comp_def.comp_id.comp_name;
                   first::NothingInt=nothing,
                   last::NothingInt=nothing,
                   before::NothingSymbol=nothing,
                   after::NothingSymbol=nothing,
                   rename::NothingPairList=nothing) # TBD: rename is not yet implemented

    # Check if component being added already exists
    has_comp(obj, comp_name) && error("Cannot add two components of the same name ($comp_name)")

    if before !== nothing && after !== nothing
        error("Cannot specify both 'before' and 'after' parameters")
    end

    # Copy the original so we don't step on other uses of this comp
    comp_def = deepcopy(comp_def)
    comp_def.name = comp_name
    parent!(comp_def, obj)

    # Handle time dimension for the component and leaving the time unset for the
    # original component template

    # (1) Propagate the first and last from the add_comp! call through the component (default to nothing)
    if has_dim(obj, :time)
        _check_first_last(obj, first = first, last = last) # check that the first and last fall in the obj's time labels
    end
    _propagate_first_last!(comp_def; first = first, last = last)
    
    # (2) If the obj has a time dimension propgagate this through the component, 
    # which also sets remaining first and last to match the time dimension.
    isa(obj, ModelDef) && !has_dim(obj, :time) && error("Cannot add a component to a Model without first setting the :time dimension")
    if has_dim(obj, :time)
        t = dimension(obj, :time)
        _propagate_time_dim!(comp_def, t)
    end

    # Add dims and insert comp
    _add_anonymous_dims!(obj, comp_def)
    _insert_comp!(obj, comp_def, before=before, after=after)

    # Return the comp since it's a copy of what was passed in
    return comp_def
end

"""
    add_comp!(
        obj::AbstractCompositeComponentDef,
        comp_id::ComponentId,
        comp_name::Symbol=comp_id.comp_name;
        first::NothingInt=nothing,
        last::NothingInt=nothing,
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component indicated by `comp_id` to the composite component indicated by `obj`. The
component is added at the end of the list unless one of the keywords `before` or `after` is
specified. Note that a copy of `comp_id` is made in the composite and assigned the give name. The optional 
arguments `first` and `last` indicate the times bounding the run period for the given component, 
which must be within the bounds of the model and if explicitly set are fixed.  These default 
to flexibly changing with the model's `:time` dimension.

[Not yet implemented:]
The optional argument `rename` can be a list of pairs indicating `original_name => imported_name`.
"""
function add_comp!(obj::AbstractCompositeComponentDef,
                   comp_id::ComponentId,
                   comp_name::Symbol=comp_id.comp_name; kwargs...)
    # println("Adding component $comp_id as :$comp_name")
    add_comp!(obj, compdef(comp_id), comp_name; kwargs...)
end

"""
    _replace!(
        obj::AbstractCompositeComponentDef,
        old_new::Pair{Symbol, ComponentId},
        before::NothingSymbol=nothing,
        after::NothingSymbol=nothing,
        reconnect::Bool=true
    )

For the pair `comp_name => comp_id` in `old_new`, replace the component with name `comp_name` in 
`obj` (a model definition or composite component definition) with the new component  
specified by `comp_id`. The component is added in the same position as the old component, 
unless one of the keywords `before` or `after` is specified for a different position. The
optional boolean argument `reconnect` with default value `true` indicates whether the existing
parameter connections should be maintained in the new component. Returns the added component def.
"""
function _replace!(obj::AbstractCompositeComponentDef, 
    old_new::Pair{Symbol, ComponentId};
    before::NothingSymbol=nothing,
    after::NothingSymbol=nothing,
    reconnect::Bool=true)

    comp_name, comp_id = old_new

    if ! has_comp(obj, comp_name)
        error("Cannot replace '$comp_name'; component not found in model.")
    end

    # Get original position if neither before nor after are specified
    if before === nothing && after === nothing
        comps = collect(compkeys(obj))
        n = length(comps)
        if n > 1
            idx = findfirst(isequal(comp_name), comps)
            if idx == n
                after = comps[idx - 1]
            else
                before = comps[idx + 1]
            end
        end
    end

    # Get the component definition of the component that is being replaced
    old_comp = compdef(obj, comp_name)

    if reconnect
        new_comp = compdef(comp_id)

        function _compare_datum(dict1, dict2)
            set1 = Set([(k, v.datatype, v.dim_names) for (k, v) in dict1])
            set2 = Set([(k, v.datatype, v.dim_names) for (k, v) in dict2])
            return set1 >= set2
        end

        # Check incoming parameters
        incoming_params = map(ipc -> ipc.dst_par_name, internal_param_conns(obj, comp_name))
        old_params = filter(pair -> pair.first in incoming_params, param_dict(old_comp))
        new_params = param_dict(new_comp)
        if ! _compare_datum(new_params, old_params)
            error("Cannot replace and reconnect; new component does not contain the necessary parameters.")
        end

        # Check outgoing variables
        _get_name(obj, name) = nameof(compdef(obj, :first))
        outgoing_vars = map(ipc -> ipc.src_var_name,
                            filter(ipc -> nameof(compdef(obj, ipc.src_comp_path)) == comp_name, internal_param_conns(obj)))
        old_vars = filter(pair -> pair.first in outgoing_vars, var_dict(old_comp))
        new_vars = var_dict(new_comp)
        if !_compare_datum(new_vars, old_vars)
            error("Cannot replace and reconnect; new component does not contain the necessary variables.")
        end

        # Check external parameter connections
        remove = []
        for epc in external_param_conns(obj, comp_name)
            param_name = epc.param_name
            if ! haskey(new_params, param_name)  # TODO: is this the behavior we want? don't error in this case? just (warn)?
                @debug "Removing external parameter connection from component $comp_name; parameter $param_name no longer exists in component."
                push!(remove, epc)
            else
                old_p = parameter(old_comp, param_name)
                new_p = new_params[param_name]
                if new_p.dim_names != old_p.dim_names
                    error("Cannot replace and reconnect; parameter $param_name in new component has different dimensions.")
                end
                if new_p.datatype != old_p.datatype
                    error("Cannot replace and reconnect; parameter $param_name in new component has different datatype.")
                end
            end
        end
        filter!(epc -> !(epc in remove), external_param_conns(obj))

        # Delete the old component from composite's namespace only, leaving parameter connections
        delete!(obj.namespace, comp_name)
    else
        # Delete the old component and all its internal and external parameter connections
        delete!(obj, comp_name)
    end

    # Re-add
    return add_comp!(obj, comp_id, comp_name; before=before, after=after)
end
