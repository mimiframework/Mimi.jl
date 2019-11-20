Base.length(obj::AbstractComponentDef) = 0   # no sub-components
Base.length(obj::AbstractCompositeComponentDef) = length(components(obj))

function compdef(comp_id::ComponentId)
    # @info "compdef: mod=$(comp_id.module_obj) name=$(comp_id.comp_name)"
    return getfield(comp_id.module_obj, comp_id.comp_name)
end

compdef(cr::ComponentReference) = find_comp(cr)

compdef(dr::AbstractDatumReference) = find_comp(dr.root, dr.comp_path)

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

"""
     is_detached(obj::AbstractComponentDef)

Return true if `obj` is not a ModelDef and it has no parent.
"""
is_detached(obj::AbstractComponentDef) = (obj.parent === nothing)
is_detached(obj::ModelDef) = false     # by definition

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

compname(dr::AbstractDatumReference) = dr.comp_path.names[end]

is_variable(dr::AbstractDatumReference)  = has_variable(find_comp(dr), nameof(dr))
is_parameter(dr::AbstractDatumReference) = has_parameter(find_comp(dr), nameof(dr))

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
    delete!(obj::AbstractCompositeComponentDef, component::Symbol)

Delete a `component` by name from composite `ccd`.
"""
function Base.delete!(ccd::AbstractCompositeComponentDef, comp_name::Symbol)
    if ! has_comp(ccd, comp_name)
        error("Cannot delete '$comp_name': component does not exist.")
    end

    comp_def = compdef(ccd, comp_name)
    delete!(ccd.namespace, comp_name)

    # Remove references to the deleted comp
    comp_path = comp_def.comp_path

    # TBD: find and delete external_params associated with deleted component? Currently no record of this.

    ipc_filter = x -> x.src_comp_path != comp_path && x.dst_comp_path != comp_path
    filter!(ipc_filter, ccd.internal_param_conns)

    epc_filter = x -> x.comp_path != comp_path
    filter!(epc_filter, ccd.external_param_conns)
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
# N.B. only composites hold comps in the namespace.
components(obj::AbstractCompositeComponentDef) = filter(istype(AbstractComponentDef), obj.namespace)

param_dict(obj::ComponentDef) = filter(istype(ParameterDef), obj.namespace)
param_dict(obj::AbstractCompositeComponentDef) = filter(istype(ParameterDefReference), obj.namespace)

var_dict(obj::ComponentDef) = filter(istype(VariableDef), obj.namespace)
var_dict(obj::AbstractCompositeComponentDef) = filter(istype(VariableDefReference), obj.namespace)

"""
    parameters(comp_def::AbstractComponentDef)

Return an iterator of the parameter definitions (or references) for `comp_def`.
"""
parameters(obj::AbstractComponentDef) = values(param_dict(obj))


"""
    variables(comp_def::AbstractComponentDef)

Return an iterator of the variable definitions (or references) for `comp_def`.
"""
variables(obj::ComponentDef)  = values(filter(istype(VariableDef), obj.namespace))
variables(obj::AbstractCompositeComponentDef) = values(filter(istype(VariableDefReference), obj.namespace))

variables(comp_id::ComponentId)  = variables(compdef(comp_id))
parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

# Return true if the component namespace has an item `name` that isa `T`
function _ns_has(comp_def::AbstractComponentDef, name::Symbol, T::DataType)
    return haskey(comp_def.namespace, name) && comp_def.namespace[name] isa T
end

function _ns_get(obj::AbstractComponentDef, name::Symbol, T::DataType)
    haskey(obj.namespace, name) || error("Item :$name was not found in component $(obj.comp_path)")
    item = obj[name]
    item isa T || error(":$name in component $(obj.comp_path) is a $(typeof(item)); expected type $T")
    return item
end

function _save_to_namespace(comp::AbstractComponentDef, key::Symbol, value::NamespaceElement)
    # Allow replacement of existing values for a key only with items of the same type.
    if haskey(comp, key)
        elt_type = typeof(comp[key])
        T = typeof(value)
        elt_type == T || error("Cannot replace item $key, type $elt_type, with object type $T in component $(comp.comp_path).")
    end

    comp.namespace[key] = value
end

"""
    datum_reference(comp::ComponentDef, datum_name::Symbol)

Create a reference to the given datum, which must already exist.
"""
function datum_reference(comp::ComponentDef, datum_name::Symbol)
    obj = _ns_get(comp, datum_name, AbstractDatumDef)
    path = @or(obj.comp_path, ComponentPath(comp.name))
    ref_type = obj isa ParameterDef ? ParameterDefReference : VariableDefReference
    return ref_type(datum_name, get_root(comp), path)
end

"""
    datum_reference(comp::AbstractCompositeComponentDef, datum_name::Symbol)

Create a reference to the given datum, which itself must be a DatumReference.
"""
datum_reference(comp::AbstractCompositeComponentDef, datum_name::Symbol) = _ns_get(comp, datum_name, AbstractDatumReference)

function Base.setindex!(comp::AbstractCompositeComponentDef, value::CompositeNamespaceElement, key::Symbol)
    _save_to_namespace(comp, key, value)
end

# Leaf components store ParameterDefReference or VariableDefReference instances in the namespace
function Base.setindex!(comp::ComponentDef, value::LeafNamespaceElement, key::Symbol)
    _save_to_namespace(comp, key, value)
end

#
# Dimensions
#

step_size(values::Vector{Int}) = (length(values) > 1 ? values[2] - values[1] : 1)

#
# TBD: should these be defined as methods of CompositeComponentDef?
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

# TBD: is this needed for composites?
function datum_size(obj::AbstractCompositeComponentDef, comp_def::ComponentDef, datum_name::Symbol)
    dims = dim_names(comp_def, datum_name)
    if dims[1] == :time
        time_length = getspan(obj, comp_def)[1]
        rest_dims = filter(x->x!=:time, dims)
        datum_size = (time_length, dim_counts(obj, rest_dims)...,)
    else
        datum_size = (dim_counts(obj, dims)...,)
    end
    return datum_size
end

"""
    _check_run_period(obj::AbstractComponentDef, first, last)

Raise an error if the component has an earlier start than `first` or a later finish than
`last`. Values of `nothing` are not checked. Composites recurse to check sub-components.
"""
function _check_run_period(obj::AbstractComponentDef, new_first, new_last)
    # @info "_check_run_period($(obj.comp_id), $(printable(new_first)), $(printable(new_last))"
    old_first = first_period(obj)
    old_last  = last_period(obj)

    if new_first !== nothing && old_first !== nothing && new_first < old_first
        error("Attempted to set first period of $(obj.comp_id) to an earlier period ($new_first) than component indicates ($old_first)")
    end

    if new_last !== nothing && old_last !== nothing && new_last > old_last
        error("Attempted to set last period of $(obj.comp_id) to a later period ($new_last) than component indicates ($old_last)")
    end

    # N.B. compdefs() returns an empty list for leaf ComponentDefs
    for subcomp in compdefs(obj)
        _check_run_period(subcomp, new_first, new_last)
    end

    nothing
end

"""
    _set_run_period!(obj::AbstractComponentDef, first, last)

Allows user to change the bounds on a AbstractComponentDef's time dimension.
An error is raised if the new time bounds are outside those of any
subcomponent, recursively.
"""
function _set_run_period!(obj::AbstractComponentDef, first, last)
    # We've disabled `first` and `last` args to add_comp!, so we don't test bounds
    # _check_run_period(obj, first, last)

    first_per = first_period(obj)
    last_per  = last_period(obj)
    changed = false

    if first !== nothing
        obj.first = first
        changed = true
    end

    if last !== nothing
        obj.last = last
        changed = true
    end

    if changed
        dirty!(obj)
    end

    nothing
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

parameter(obj::ComponentDef, name::Symbol) = _ns_get(obj, name, ParameterDef)

parameter(obj::AbstractCompositeComponentDef, name::Symbol) = _ns_get(obj, name, ParameterDefReference)

parameter(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol) = parameter(compdef(obj, comp_name), param_name)

parameter(dr::ParameterDefReference) = parameter(compdef(dr), nameof(dr))

has_parameter(comp_def::ComponentDef, name::Symbol) = _ns_has(comp_def, name, ParameterDef)

has_parameter(comp_def::AbstractCompositeComponentDef, name::Symbol) = _ns_has(comp_def, name, ParameterDefReference)

function parameter_unit(obj::AbstractComponentDef, param_name::Symbol)
    param = parameter(obj, param_name)
    return unit(param)
end

"""
    parameter_dimensions(obj::AbstractComponentDef, param_name::Symbol)

Return the names of the dimensions of parameter `param_name` exposed in the composite 
component definition indicated by`obj`.
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
    set_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath,
                value_dict::Dict{Symbol, Any}, param_names)

Call `set_param!()` for each name in `param_names`, retrieving the corresponding value from
`value_dict[param_name]`.
"""
function set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, value_dict::Dict{Symbol, Any}, param_names)
    for param_name in param_names
        set_param!(obj, comp_name, value_dict, param_name)
    end
end

"""
    set_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol,
               value_dict::Dict{Symbol, Any}, dims=nothing)

Call `set_param!()` with `param_name` and a value dict in which `value_dict[param_name]` references
the value of parameter `param_name`.
"""
function set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, value_dict::Dict{Symbol, Any},
                    param_name::Symbol, dims=nothing)
    value = value_dict[param_name]
    set_param!(obj, comp_name, param_name, value, dims)
end

function set_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol, value, dims=nothing)
    # @info "set_param!($(obj.comp_id), $comp_path, $param_name, $value)"
    comp = find_comp(obj, comp_path)
    @or(comp, error("Component with path $comp_path not found"))
    set_param!(comp.parent, nameof(comp), param_name, value, dims)
end

"""
    set_param!(obj::AbstractCompositeComponentDef, path::AbstractString, param_name::Symbol, value, dims=nothing)

Set a parameter for a component with the given relative path (as a string), in which "/x" means the
component with name `:x` beneath the root of the hierarchy in which `obj` is found. If the path does
not begin with "/", it is treated as relative to `obj`.
"""
function set_param!(obj::AbstractCompositeComponentDef, path::AbstractString, param_name::Symbol, value, dims=nothing)
    # @info "set_param!($(obj.comp_id), $path, $param_name, $value)"
    set_param!(obj, comp_path(obj, path), param_name, value, dims)
end

"""
    set_param!(obj::AbstractCompositeComponentDef, path::AbstractString, value, dims=nothing)

Set a parameter using a colon-delimited string to specify the component path (before the ":")
and the param name (after the ":").
"""
function set_param!(obj::AbstractCompositeComponentDef, path::AbstractString, value, dims=nothing)
    comp_path, param_name = split_datum_path(obj, path)
    set_param!(obj, comp_path, param_name, value, dims)
end

"""
    set_param!(obj::AbstractCompositeComponentDef, param_name::Symbol, value, dims=nothing)

Set the value of a parameter exposed in `obj` by following the ParameterDefReference. This
method cannot be used on composites that are subcomponents of another composite.
"""
function set_param!(obj::AbstractCompositeComponentDef, param_name::Symbol, value, dims=nothing)
    if obj.parent !== nothing
        error("Parameter setting is supported only for top-level composites. $(obj.comp_path) is a subcomponent.")
    end
    param_ref = obj[param_name]
    set_param!(obj, param_ref.comp_path, param_ref.name, value, dims=dims)
end

"""
    set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter `name` of a component `comp_name` in a composite `obj` to a given `value`. The
`value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' is a
list of the dimension names of the provided data, and will be used to check that
they match the model's index labels.
"""
function set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    # @info "set_param!($(obj.comp_id), $comp_name, $param_name, $value)"
    # perform possible dimension and labels checks
    if value isa NamedArray
        dims = dimnames(value)
    end

    if dims !== nothing
        check_parameter_dimensions(obj, value, dims, param_name)
    end

    comp_def = compdef(obj, comp_name)
    comp_param_dims = parameter_dimensions(comp_def, param_name)
    num_dims = length(comp_param_dims)

    param  = parameter(comp_def, param_name)
    data_type = param.datatype
    dtype = Union{Missing, (data_type == Number ? number_type(obj) : data_type)}

    if length(comp_param_dims) > 0

        # convert the number type and, if NamedArray, convert to Array
        if dtype <: AbstractArray
            value = convert(dtype, value)
        else
            # check that number of dimensions matches
            value_dims = length(size(value))
            if num_dims != value_dims
                error("Mismatched data size for a set parameter call: dimension :$param_name in $(comp_name) has $num_dims dimensions; indicated value has $value_dims dimensions.")
            end
            value = convert(Array{dtype, num_dims}, value)
        end

        ti = get_time_index_position(obj, comp_name, param_name)

        if ti != nothing   # there is a time dimension
            T = eltype(value)

            if num_dims == 0
                values = value
            else
                # Use the first from the comp_def if it has it, else use the tree root (usu. a ModelDef)
                first = first_period(obj, comp_def)
                first === nothing && @warn "set_param!: first === nothing"

                if isuniform(obj)
                    stepsize = step_size(obj)
                    values = TimestepArray{FixedTimestep{first, stepsize}, T, num_dims, ti}(value)
                else
                    times = time_labels(obj)
                    # use the first from the comp_def
                    first_index = findfirst(isequal(first), times)
                    values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, num_dims, ti}(value)
                end
            end
        else
            values = value
        end

        set_external_array_param!(obj, param_name, values, comp_param_dims)

    else # scalar parameter case
        value = convert(dtype, value)
        set_external_scalar_param!(obj, param_name, value)
    end

    # connect_param! calls dirty! so we don't have to
    # @info "Calling connect_param!($(printable(obj === nothing ? nothing : obj.comp_id)), $comp_name, $param_name)"
    connect_param!(obj, comp_name, param_name, param_name)
    nothing
end

#
# Variables
#
variable(obj::ComponentDef, name::Symbol) = _ns_get(obj, name, VariableDef)

variable(obj::AbstractCompositeComponentDef, name::Symbol) = _ns_get(obj, name, VariableDefReference)

variable(comp_id::ComponentId, var_name::Symbol) = variable(compdef(comp_id), var_name)

variable(obj::AbstractCompositeComponentDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(obj, comp_name), var_name)

function variable(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    comp_def = find_comp(obj, comp_path)
    return variable(comp_def, var_name)
end

variable(dr::VariableDefReference) = variable(compdef(dr), nameof(dr))



has_variable(comp_def::ComponentDef, name::Symbol) = _ns_has(comp_def, name, VariableDef)

has_variable(comp_def::AbstractCompositeComponentDef, name::Symbol) = _ns_has(comp_def, name, VariableDefReference)

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

# Smooth over difference between VariableDef and VariableDefReference
unit(obj::AbstractDatumDef) = obj.unit
unit(obj::VariableDefReference)  = variable(obj).unit
unit(obj::ParameterDefReference) = parameter(obj).unit

"""
    variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)

Return the names of the dimensions of variable `var_name` exposed in the composite 
component definition indicated by`obj` along the component path `comp_path`.
"""
function variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    var = variable(obj, comp_path, var_name)
    return dim_names(var)
end

"""
    variable_dimensions(obj::AbstractComponentDef, name::Symbol)

Return the names of the dimensions of variable `name` exposed in the composite 
component definition indicated by`obj`.
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

function getspan(obj::AbstractCompositeComponentDef, comp_def::ComponentDef)
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

    # @info "parent obj comp_path: $(printable(obj.comp_path))"
    # @info "inserted comp's path: $(comp_def.comp_path)"
    dirty!(obj)

    nothing
end

"""
Return True if time Dimension `outer` contains `inner`.
"""
function time_contains(outer::Dimension, inner::Dimension)
    outer_idx = keys(outer)
    inner_idx = keys(inner)

    return outer_idx[1] <= inner_idx[1] && outer_idx[end] >= inner_idx[end]
end

function _find_var_par(parent::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                       comp_name::Symbol, datum_name::Symbol)
    path = ComponentPath(parent.comp_path, comp_name)
    root = get_root(parent)

    root === nothing && error("Component $(parent.comp_id) does not have a root")

    if has_variable(comp_def, datum_name)
        return VariableDefReference(datum_name, root, path)
    end

    if has_parameter(comp_def, datum_name)
        return ParameterDefReference(datum_name, root, path)
    end

    error("Component $(comp_def.comp_id) does not have a data item named $datum_name")
end

"""
    propagate_time!(obj::AbstractComponentDef, t::Dimension)

Propagate a time dimension down through the comp def tree.
"""
function propagate_time!(obj::AbstractComponentDef, t::Dimension)
    set_dimension!(obj, :time, t)

    obj.first = firstindex(t)
    obj.last  = lastindex(t)

    for c in compdefs(obj)      # N.B. compdefs returns empty list for leaf nodes
        propagate_time!(c, t)
    end
end

"""
    add_comp!(
        obj::AbstractCompositeComponentDef, 
        comp_def::AbstractComponentDef,
        comp_name::Symbol=comp_def.comp_id.comp_name; 
        before::NothingSymbol=nothing, 
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component `comp_def` to the composite component indicated by `obj`. The component is
added at the end of the list unless one of the keywords `before` or `after` is specified.
Note that a copy of `comp_id` is made in the composite and assigned the give name. The optional
argument `rename` can be a list of pairs indicating `original_name => imported_name`.
"""
function add_comp!(
    obj::AbstractCompositeComponentDef, 
    comp_def::AbstractComponentDef,
    comp_name::Symbol=comp_def.comp_id.comp_name;
    before::NothingSymbol=nothing, 
    after::NothingSymbol=nothing,
    rename::NothingPairList=nothing
)

    # Check if component being added already exists
    has_comp(obj, comp_name) && error("Cannot add two components of the same name ($comp_name)")

    if before !== nothing && after !== nothing
        error("Cannot specify both 'before' and 'after' parameters")
    end

    # check time constraints if the time dimension has been set
    if has_dim(obj, :time)
        # error("Cannot add component to composite without first setting time dimension.")
        propagate_time!(comp_def, dimension(obj, :time))
    end

    # Copy the original so we don't step on other uses of this comp
    comp_def = deepcopy(comp_def)
    comp_def.name = comp_name
    parent!(comp_def, obj)

    _add_anonymous_dims!(obj, comp_def)
    _insert_comp!(obj, comp_def, before=before, after=after)

    # Set parameters to any specified defaults, but only for leaf components
    if is_leaf(comp_def)
        for param in parameters(comp_def)
            if param.default !== nothing
                x = printable(obj === nothing ? "obj==nothing" : obj.comp_id)
                set_param!(obj, comp_name, nameof(param), param.default)
            end
        end
    end

    # Return the comp since it's a copy of what was passed in
    return comp_def
end

"""
    add_comp!(
        obj::AbstractCompositeComponentDef, 
        comp_id::ComponentId,
        comp_name::Symbol=comp_id.comp_name;
        before::NothingSymbol=nothing, 
        after::NothingSymbol=nothing,
        rename::NothingPairList=nothing
    )

Add the component indicated by `comp_id` to the composite component indicated by `obj`. The
component is added at the end of the list unless one of the keywords `before` or `after` is
specified. Note that a copy of `comp_id` is made in the composite and assigned the give name.
The optional argument `rename` can be a list of pairs indicating `original_name => imported_name`.
"""
function add_comp!(
    obj::AbstractCompositeComponentDef, 
    comp_id::ComponentId,
    comp_name::Symbol=comp_id.comp_name;
    before::NothingSymbol=nothing, 
    after::NothingSymbol=nothing,
    rename::NothingPairList=nothing
)
    # println("Adding component $comp_id as :$comp_name")
    add_comp!(obj, compdef(comp_id), comp_name, before=before, after=after, rename=rename)
end

"""
    replace_comp!(
        obj::AbstractCompositeComponentDef, 
        comp_id::ComponentId,
        comp_name::Symbol=comp_id.comp_name;
        before::NothingSymbol=nothing, 
        after::NothingSymbol=nothing,
        reconnect::Bool=true
    )

Replace the component with name `comp_name` in composite component definition `obj` with the
component `comp_id` using the same name. The component is added in the same position as the
old component, unless one of the keywords `before` or `after` is specified. The component is
added with the same first and last values, unless the keywords `first` or `last` are specified.
Optional boolean argument `reconnect` with default value `true` indicates whether the existing
parameter connections should be maintained in the new component. Returns the added comp def.
"""
function replace_comp!(
    obj::AbstractCompositeComponentDef, 
    comp_id::ComponentId,
    comp_name::Symbol=comp_id.comp_name;
    before::NothingSymbol=nothing, 
    after::NothingSymbol=nothing,
    reconnect::Bool=true
)

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
