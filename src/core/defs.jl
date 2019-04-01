compdef(comp_id::ComponentId) = getfield(getfield(Main, comp_id.module_name), comp_id.comp_name)

compdef(cr::ComponentReference) = find_comp(cr)

compdef(obj::AbstractCompositeComponentDef, path::ComponentPath) = find_comp(obj, path)

compdef(obj::AbstractCompositeComponentDef, comp_name::Symbol) = obj.comps_dict[comp_name]

has_comp(c::AbstractCompositeComponentDef, comp_name::Symbol) = haskey(c.comps_dict, comp_name)

compdefs(c::AbstractCompositeComponentDef) = values(c.comps_dict)
compkeys(c::AbstractCompositeComponentDef) = keys(c.comps_dict)

# Allows method to be called on leaf component defs, which sometimes simplifies code.
compdefs(c::ComponentDef) = []

compmodule(comp_id::ComponentId) = comp_id.module_name
compname(comp_id::ComponentId)   = comp_id.comp_name

compmodule(obj::AbstractComponentDef) = compmodule(obj.comp_id)
compname(obj::AbstractComponentDef)   = compname(obj.comp_id)

compnames() = map(compname, compdefs())

# Access a subcomponent as comp[:name]
Base.getindex(obj::AbstractCompositeComponentDef, name::Symbol) = obj.comps_dict[name]

# TBD: deprecated
function reset_compdefs(reload_builtins=true)
    if reload_builtins
        compdir = joinpath(@__DIR__, "..", "components")
        load_comps(compdir)
    end
end

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

Base.parent(obj::AbstractComponentDef) = obj.parent

first_period(comp_def::ComponentDef) = comp_def.first
last_period(comp_def::ComponentDef)  = comp_def.last

function first_period(comp::AbstractCompositeComponentDef)
    values = filter(!isnothing, [first_period(c) for c in compdefs(comp)])
    return length(values) > 0 ? min(values...) : nothing
end

function last_period(comp::AbstractCompositeComponentDef)
    values = filter(!isnothing, [last_period(c) for c in compdefs(comp)])
    return length(values) > 0 ? max(values...) : nothing
end

function first_period(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef)
    period = first_period(comp_def)
    return period === nothing ? time_labels(obj)[1] : period
end

function last_period(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef)
    period = last_period(comp_def)
    return period === nothing ? time_labels(obj)[end] : period
end

compname(dr::AbstractDatumReference) = dr.comp_path.names[end]
#@delegate compmodule(dr::DatumReference) => comp_id

is_variable(dr::AbstractDatumReference) = false
is_parameter(dr::AbstractDatumReference) = false

is_variable(dr::VariableDefReference)   = has_variable(find_comp(dr), nameof(dr))
is_parameter(dr::ParameterDefReference) = has_parameter(find_comp(dr), nameof(dr))

number_type(md::ModelDef) = md.number_type

function number_type(obj::AbstractCompositeComponentDef)
    root = get_root(obj)
    # TBD: hack alert. Need to allow number_type to be specified
    # for composites that are not yet connected to a ModelDef?
    return root isa ModelDef ? root.number_type : Float64
end

# TBD: should be numcomps()
numcomponents(obj::AbstractComponentDef) = 0   # no sub-components
numcomponents(obj::AbstractCompositeComponentDef) = length(obj.comps_dict)

"""
    delete!(obj::AbstractCompositeComponentDef, component::Symbol)

Delete a `component` by name from a model definition `m`.
"""
function Base.delete!(ccd::AbstractCompositeComponentDef, comp_name::Symbol)
    if ! has_comp(ccd, comp_name)
        error("Cannot delete '$comp_name': component does not exist.")
    end

    comp_def = compdef(ccd, comp_name)
    delete!(ccd.comps_dict, comp_name)

    # Remove references to the deleted comp
    comp_path = comp_def.comp_path
    exports = ccd.exports

    for (key, dr) in exports
        if dr.comp_path == comp_path
            delete!(exports, key)
        end
    end

    # TBD: find and delete external_params associated with deleted component? Currently no record of this.

    ipc_filter = x -> x.src_comp_path != comp_path && x.dst_comp_path != comp_path
    filter!(ipc_filter, ccd.internal_param_conns)

    epc_filter = x -> x.comp_path != comp_path
    filter!(epc_filter, ccd.external_param_conns)
end

#
# Dimensions
#

function add_dimension!(comp::AbstractComponentDef, name)
    # generally, we add dimension name with nothing instead of a Dimension instance,
    # but in the case of an Int name, we create the "anonymous" dimension on the fly.
    dim = (name isa Int) ? Dimension(name) : nothing
    comp.dim_dict[Symbol(name)] = dim                         # TBD: test this
end

# Note that this operates on the registered comp, not one added to a composite
add_dimension!(comp_id::ComponentId, name) = add_dimension!(compdef(comp_id), name)

function dim_names(ccd::AbstractCompositeComponentDef)
    dims = OrderedSet{Symbol}()             # use a set to eliminate duplicates
    for cd in compdefs(ccd)
        union!(dims, keys(dim_dict(cd)))    # TBD: test this
    end

    return collect(dims)
end

dim_names(comp_def::AbstractComponentDef, datum_name::Symbol) = dim_names(datumdef(comp_def, datum_name))

dim_count(def::AbstractDatumDef) = length(dim_names(def))

function step_size(values::Vector{Int})
    return length(values) > 1 ? values[2] - values[1] : 1
end

#
# TBD: should these be defined as methods of CompositeComponentDef?
#
function step_size(obj::AbstractCompositeComponentDef)
    keys::Vector{Int} = time_labels(obj)
    return step_size(keys)
end

function first_and_step(obj::AbstractCompositeComponentDef)
    keys::Vector{Int} = time_labels(obj) # labels are the first times of the model runs
    return first_and_step(keys)
end

function first_and_step(values::Vector{Int})
     return values[1], step_size(values)
end

first_and_last(obj::AbstractComponentDef) = (obj.first, obj.last)

function time_labels(obj::AbstractCompositeComponentDef)
    keys::Vector{Int} = dim_keys(obj, :time)
    return keys
end

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

# Symbols are added to the dim_dict in @defcomp (with value of nothing), but are set later using set_dimension!
has_dim(obj::AbstractCompositeComponentDef, name::Symbol) = (haskey(obj.dim_dict, name) && obj.dim_dict[name] !== nothing)

isuniform(obj::AbstractCompositeComponentDef) = obj.is_uniform

set_uniform!(obj::AbstractCompositeComponentDef, value::Bool) = (obj.is_uniform = value)

dimension(obj::AbstractCompositeComponentDef, name::Symbol) = obj.dim_dict[name]

dim_names(obj::AbstractCompositeComponentDef, dims::Vector{Symbol}) = [dimension(obj, dim) for dim in dims]

dim_count_dict(obj::AbstractCompositeComponentDef) = Dict([name => length(value) for (name, value) in dim_dict(obj)])

# deprecated?
#dim_key_dict(obj::AbstractCompositeComponentDef) = Dict([name => collect(keys(dim)) for (name, dim) in dimensions(obj)])

dim_counts(obj::AbstractCompositeComponentDef, dims::Vector{Symbol}) = [length(dim) for dim in dim_names(obj, dims)]
dim_count(obj::AbstractCompositeComponentDef, name::Symbol) = length(dimension(obj, name))

dim_keys(obj::AbstractCompositeComponentDef, name::Symbol)   = collect(keys(dimension(obj, name)))
dim_values(obj::AbstractCompositeComponentDef, name::Symbol) = collect(values(dimension(obj, name)))

# For debugging only
function _show_run_period(obj::AbstractComponentDef, first, last)
    first = (first === nothing ? :nothing : first)
    last  = (last  === nothing ? :nothing : last)
    which = (is_leaf(obj) ? :leaf : :composite)
    @info "Setting run period for $which $(nameof(obj)) to ($first, $last)"
end

"""
    set_run_period!(obj::ComponentDef, first, last)

Allows user to narrow the bounds on the time dimension.

If the component has an earlier start than `first` or a later finish than `last`,
the values are reset to the tighter bounds. Values of `nothing` are left unchanged.
Composites recurse on sub-components.
"""
function set_run_period!(obj::AbstractComponentDef, first, last)
    #_show_run_period(obj, first, last)
    first_per = first_period(obj)
    last_per  = last_period(obj)
    changed = false

    if first !== nothing
        if first_per !== nothing && first_per < first
            @warn "Resetting $(nameof(comp_def)) component's first timestep to $first"
        end
        obj.first = first
        changed = true
    end

    if last !== nothing
        if last_per !== nothing && last_per > last
            @warn "Resetting $(nameof(comp_def)) component's last timestep to $last"
        end
        obj.last = last
        changed = true
    end

    if changed
        dirty!(obj)
    end

    # N.B. compdefs() returns an empty list for leaf ComponentDefs
    for subcomp in compdefs(obj)
        set_run_period!(subcomp, first, last)
    end

    nothing
end

"""
    set_dimension!(ccd::CompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange})

Set the values of `ccd` dimension `name` to integers 1 through `count`, if `keys` is
an integer; or to the values in the vector or range if `keys` is either of those types.
"""
function set_dimension!(ccd::AbstractCompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange})
    redefined = has_dim(ccd, name)
    if redefined
        @warn "Redefining dimension :$name"
    end

    if name == :time
        set_uniform!(ccd, isuniform(keys))
        #set_run_period!(ccd, keys[1], keys[end])
    end

    return set_dimension!(ccd, name, Dimension(keys))
end

function set_dimension!(obj::AbstractComponentDef, name::Symbol, dim::Dimension)
    dirty!(obj)
    obj.dim_dict[name] = dim

    if name == :time
        for subcomp in compdefs(obj)
            set_dimension!(subcomp, :time, dim)
        end
    end
    return dim
end

# helper functions used to determine if the provided time values are
# a uniform range.

function all_equal(values)
    return all(map(val -> val == values[1], values[2:end]))
end

function isuniform(values)
   if length(values) == 0
        return false
   else
        return all_equal(diff(collect(values)))
   end
end

# needed when time dimension is defined using a single integer
function isuniform(values::Int)
    return true
end

#
# Parameters
#

# Callable on both ParameterDef and VariableDef
dim_names(obj::AbstractDatumDef) = obj.dim_names

function addparameter(comp_def::AbstractComponentDef, name, datatype, dimensions, description, unit, default)
    p = ParameterDef(name, datatype, dimensions, description, unit, default)
    comp_def.parameters[name] = p
    dirty!(comp_def)
    return p
end

function addparameter(comp_id::ComponentId, name, datatype, dimensions, description, unit, default)
    addparameter(compdef(comp_id), name, datatype, dimensions, description, unit, default)
end

"""
    parameters(comp_def::ComponentDef)

Return a list of the parameter definitions for `comp_def`.
"""
parameters(obj::AbstractComponentDef) = values(obj.parameters)

function parameters(ccd::AbstractCompositeComponentDef)
    pars = ccd.parameters

    # return cached parameters, if any
    if length(pars) == 0
        for (name, dr) in ccd.exports
            cd = find_comp(dr)
            
            if cd === nothing
                @info "find_comp failed on path: $(printable(dr.comp_path)), name: $(printable(dr.name)), root: $(printable(dr.root.comp_id))"
            end

            if has_parameter(cd, nameof(dr))
                pars[name] = parameter(cd, nameof(dr))
            end
        end
    end

    return values(pars)
end

"""
    parameters(comp_id::ComponentId)

Return a list of the parameter definitions for `comp_id`.
"""
parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

# TBD: deprecated?
# parameters(obj::ParameterDefReference) = parameters(obj.comp_id)

"""
    parameter_names(md::ModelDef, comp_name::Symbol)

Return a list of all parameter names for a given component `comp_name` in a model def `md`.
"""
parameter_names(md::ModelDef, comp_name::Symbol) = parameter_names(compdef(md, comp_name))

#parameter_names(comp_def::ComponentDef) = [nameof(param) for param in parameters(comp_def)]
parameter_names(comp_def::AbstractComponentDef) = collect(keys(comp_def.parameters))

parameter(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol) = parameter(compdef(obj, comp_name), param_name)

parameter(dr::ParameterDefReference) = parameter(compdef(dr), nameof(dr))

function _parameter(obj::AbstractComponentDef, name::Symbol)
    try
        return obj.parameters[name]
    catch
        error("Parameter $name was not found in component $(nameof(obj))")
    end
end

function parameter(obj::ComponentDef, name::Symbol)
    _parameter(obj, name)
end

function parameter(obj::AbstractCompositeComponentDef, name::Symbol)
    if ! is_exported(obj, name)
        error("Parameter $name is not exported by composite component $(obj.comp_path)")
    end
    _parameter(obj, name)
end

has_parameter(comp_def::AbstractComponentDef, name::Symbol) = haskey(comp_def.parameters, name)

function parameter_unit(obj::AbstractComponentDef, param_name::Symbol)
    param = _parameter(obj, param_name)
    return param.unit
end

function parameter_dimensions(obj::AbstractComponentDef, param_name::Symbol)
    param = _parameter(obj, param_name)
    return dim_names(param)
end

function parameter_unit(obj::AbstractComponentDef, comp_name::Symbol, param_name::Symbol)
    return parameter_unit(compdef(obj, comp_name), param_name)
end

function parameter_dimensions(obj::AbstractComponentDef, comp_name::Symbol, param_name::Symbol)
    return parameter_dimensions(compdef(obj, comp_name), param_name)
end


function set_param!(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, param_name::Symbol, value, dims=nothing)
    @info "set_param!($(obj.comp_id), $comp_path, $param_name, $value)"
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
    @info "set_param!($(obj.comp_id), $path, $param_name, $value)"
    set_param!(obj, _comp_path(obj, path), param_name, value, dims)
end

"""
    set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter `name` of a component `comp_name` in a composite `obj` to a given `value`. The
`value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' is a
list of the dimension names of the provided data, and will be used to check that
they match the model's index labels.
"""
function set_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    @info "set_param!($(obj.comp_id), $comp_name, $param_name, $value)"
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
    dtype = data_type == Number ? number_type(obj) : data_type

    if length(comp_param_dims) > 0

        # convert the number type and, if NamedArray, convert to Array
        if dtype <: AbstractArray
            value = convert(dtype, value)
        else
            #check that number of dimensions matches
            value_dims = length(size(value))
            if num_dims != value_dims
                error("Mismatched data size for a set parameter call: dimension :$param_name in $(comp_name) has $num_dims dimensions; indicated value has $value_dims dimensions.")
            end
            value = convert(Array{dtype, num_dims}, value)
        end

        if comp_param_dims[1] == :time
            T = eltype(value)

            if num_dims == 0
                values = value
            else
                # Want to use the first from the comp_def if it has it, if not use ModelDef
                first = first_period(obj, comp_def)

                if isuniform(obj)
                    stepsize = step_size(obj)
                    values = TimestepArray{FixedTimestep{first, stepsize}, T, num_dims}(value)
                else
                    times = time_labels(obj)
                    #use the first from the comp_def
                    first_index = findfirst(isequal(first), times)
                    values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, num_dims}(value)
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
    # @info "Calling connect_param!($(printable(obj === nothing ? nothing : obj.comp_id))"
    connect_param!(obj, comp_name, param_name, param_name)
    nothing
end

#
# Variables
#
variables(comp_def::AbstractComponentDef) = values(comp_def.variables)

# TBD: if we maintain vars/pars dynamically, this can be dropped
function variables(ccd::AbstractCompositeComponentDef)
    vars = ccd.variables

    # return cached variables, if any
    if length(vars) == 0
        for (dr, name) in ccd.exports
            cd = compdef(dr.comp_id)
            if has_variable(cd, nameof(dr))
                vars[name] = variable(cd, nameof(dr))
            end
        end
    end

    return values(vars)
end

variables(comp_id::ComponentId) = variables(compdef(comp_id))

# TBD: Not sure this makes sense
# variables(dr::DatumReference) = variables(dr.comp_id)

# TBD: Perhaps define _variable to behave as below, and have the public version
# check it's exported before returning it. (Could error("exists but not exported?"))
function variable(comp_def::AbstractComponentDef, var_name::Symbol)
    # TBD test this can be dropped if we maintain vars/pars dynamically
    if is_composite(comp_def)
        variables(comp_def)  # make sure values have been gathered
    end

    try
        return comp_def.variables[var_name]
    catch KeyError
        error("Variable $var_name was not found in component $(comp_def.comp_id)")
    end
end

variable(comp_id::ComponentId, var_name::Symbol) = variable(compdef(comp_id), var_name)

variable(obj::AbstractCompositeComponentDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(obj, comp_name), var_name)

function variable(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    comp_def = find_comp(obj, comp_path)
    return variable(comp_def, var_name)
end

variable(obj::VariableDefReference) = variable(compdef(obj), nameof(dr))

has_variable(comp_def::AbstractComponentDef, name::Symbol) = haskey(comp_def.variables, name)

"""
    variable_names(md::AbstractCompositeComponentDef, comp_name::Symbol)

Return a list of all variable names for a given component `comp_name` in a model def `md`.
"""
variable_names(obj::AbstractCompositeComponentDef, comp_name::Symbol) = variable_names(compdef(obj, comp_name))

variable_names(comp_def::AbstractComponentDef) = [nameof(var) for var in variables(comp_def)]


function variable_unit(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    var = variable(obj, comp_path, var_name)
    return var.unit
end

function variable_dimensions(obj::AbstractCompositeComponentDef, comp_path::ComponentPath, var_name::Symbol)
    var = variable(obj, comp_path, var_name)
    return dim_names(var)
end

function variable_unit(obj::AbstractComponentDef, name::Symbol)
    var = variable(obj, name)
    return var.unit
end

function variable_dimensions(obj::AbstractComponentDef, name::Symbol)
    var = variable(obj, name)
    return dim_names(var)
end


# Add a variable to a ComponentDef. CompositeComponents have no vars of their own,
# only references to vars in components contained within.
function addvariable(comp_def::ComponentDef, name, datatype, dimensions, description, unit)
    var_def = VariableDef(name, datatype, dimensions, description, unit)
    comp_def.variables[name] = var_def
    return var_def
end

"""
    addvariables(obj::CompositeComponentDef, exports::Vector{Pair{AbstractDatumReference, Symbol}})

Add all exported variables to a CompositeComponentDef.
"""
function addvariables(obj::AbstractCompositeComponentDef, exports::Vector{Pair{AbstractDatumReference, Symbol}})
    # TBD: this needs attention
    for (dr, exp_name) in exports
        addvariable(obj, variable(obj, nameof(variable)), exp_name)
    end
end

# Add a variable to a ComponentDef referenced by ComponentId
function addvariable(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addvariable(compdef(comp_id), name, datatype, dimensions, description, unit)
end

#
# Other
#

# Return the number of timesteps a given component in a model will run for.
function getspan(obj::AbstractCompositeComponentDef, comp_name::Symbol)
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

function _append_comp!(obj::AbstractCompositeComponentDef, comp_name::Symbol, comp_def::AbstractComponentDef)
   obj.comps_dict[comp_name] = comp_def
end

function _add_anonymous_dims!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef)
    for (name, dim) in filter(pair -> pair[2] !== nothing, comp_def.dim_dict)
        # @info "Setting dimension $name to $dim"
        set_dimension!(obj, name, dim)
    end
end

function comps_dict!(obj::AbstractCompositeComponentDef, comps::OrderedDict{Symbol, AbstractComponentDef})
    obj.comps_dict = comps
    dirty!(obj)
end

# Save a back-pointer to the container object
function parent!(child::AbstractComponentDef, parent::AbstractCompositeComponentDef)
    child.parent = parent
    nothing
end

# Recursively ascend the component tree structure to find the root node
get_root(node::AbstractComponentDef) = (node.parent === nothing ? node : get_root(node.parent))

const NothingInt    = Union{Nothing, Int}
const NothingSymbol = Union{Nothing, Symbol}
const ExportList    = Vector{Union{Symbol, Pair{Symbol, Symbol}}}

function _insert_comp!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef;
                       before::NothingSymbol=nothing, after::NothingSymbol=nothing)

    comp_name = nameof(comp_def)

    if before === nothing && after === nothing
        _append_comp!(obj, comp_name, comp_def)   # add it to the end
    else
        new_comps = OrderedDict{Symbol, AbstractComponentDef}()

        if before !== nothing
            if ! has_comp(obj, before)
                error("Component to add before ($before) does not exist")
            end

            for (k, v) in obj.comps_dict
                if k == before
                    new_comps[comp_name] = comp_def
                end
                new_comps[k] = v
            end

        else    # after !== nothing, since we've handled all other possibilities above
            if ! has_comp(obj, after)
                error("Component to add before ($before) does not exist")
            end

            for (k, v) in obj.comps_dict
                new_comps[k] = v
                if k == after
                    new_comps[comp_name] = comp_def
                end
            end
        end

        comps_dict!(obj, new_comps)
    end

    comp_path!(comp_def, obj)
    @info "parent obj comp_path: $(printable(obj.comp_path))"
    @info "inserted comp's path: $(comp_def.comp_path)"
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

"""
Propagate a time dimension down through the comp def tree.
"""
function  _propagate_time(obj::AbstractComponentDef, t::Dimension)
    set_dimension!(obj, :time, t)

    for c in compdefs(obj)      # N.B. compdefs returns empty list for leaf nodes
        _propagate_time(c, t)
    end
end

function _find_var_par(parent::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                       comp_name::Symbol, datum_name::Symbol)
    path = ComponentPath(parent.comp_path, comp_name)
    root = get_root(parent)

    root === nothing && error("Component $(parent.comp_id) does have a root")

    # @info "comp path: $path, datum_name: $datum_name"

    # for composites, check that the named vars/pars are exported?
    # if is_composite(comp_def)

    if has_variable(comp_def, datum_name)
        return VariableDefReference(datum_name, root, path)
    end

    if has_parameter(comp_def, datum_name)
        return ParameterDefReference(datum_name, root, path)
    end

    error("Component $(comp_def.comp_id) does not have a data item named $datum_name")
end

"""
    add_comp!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
              comp_name::Symbol=comp_def.comp_id.comp_name;
              exports=nothing, first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_def` to the composite components indicated by `obj`. The component
is added at the end of the list unless one of the keywords, `first`, `last`, `before`, `after`. Note that
a copy of `comp_def` is created and inserted into the composite under the given `comp_name`.
The `exports` arg identifies which vars/pars to make visible to the next higher composite level, and with
what names. If `nothing`, everything is exported. The first element of a pair indicates the symbol to export
from comp_def to the composite, the second element allows this var/par to have a new name in the composite.
A symbol alone means to use the name unchanged, i.e., [:X, :Y] implies [:X => :X, :Y => :Y]
"""
function add_comp!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                   comp_name::Symbol=comp_def.comp_id.comp_name;
                   exports=nothing,
                   first::NothingInt=nothing, last::NothingInt=nothing,
                   before::NothingSymbol=nothing, after::NothingSymbol=nothing)

    # If not specified, export all var/pars. Caller can pass empty list to export nothing.
    # TBD: actually, might work better to export nothing unless declared as such.
    if exports === nothing
        exports = []
        # exports = [variable_names(comp_def)..., parameter_names(comp_def)...]
    end

    for item in exports
        if item isa Pair
            (name, export_name) = item
        elseif item isa Symbol
            name = export_name = item
        else
            error("Exports argument to add_comp! must be pair or symbol, got: $item")
        end

        # TBD: should this just add to obj.variables / obj.parameters dicts?
        # Those dicts hold ParameterDef / VariableDef, which we want to reference, not
        # duplicate when building instances. One approach would be for the build step
        # to create a dict on objectid(x) to store/find the generated var/param.
        if haskey(obj.exports, export_name)
            error("Exports may not include a duplicate name ($export_name)")
        end

        obj.exports[export_name] = _find_var_par(obj, comp_def, comp_name, name)
    end

    # Check if component being added already exists
    if has_comp(obj, comp_name)
        error("Cannot add two components of the same name ($comp_name)")
    end

    # check that a time dimension has been set
    if has_dim(obj, :time)
        # error("Cannot add component to composite without first setting time dimension.")

        # check that first and last are within the model's time index range
        time_index = dim_keys(obj, :time)

        if first !== nothing && first < time_index[1]
            error("Cannot add component $comp_name with first time before first of model's time index range.")
        end

        if last !== nothing && last > time_index[end]
            error("Cannot add component $comp_name with last time after end of model's time index range.")
        end

        if before !== nothing && after !== nothing
            error("Cannot specify both 'before' and 'after' parameters")
        end

        _propagate_time(comp_def, dimension(obj, :time))
    end

    # Copy the original so we don't step on other uses of this comp
    comp_def = deepcopy(comp_def)
    comp_def.name = comp_name
    parent!(comp_def, obj)

    set_run_period!(comp_def, first, last)
    _add_anonymous_dims!(obj, comp_def)
    _insert_comp!(obj, comp_def, before=before, after=after)

    ########################################################################
    # TBD: set parameter values only in ComponentDefs, not in Composites
    ########################################################################

    # Set parameters to any specified defaults
    for param in parameters(comp_def)
        if param.default !== nothing
            x = printable(obj === nothing ? "obj==nothing" : obj.comp_id)
            @info "add_comp! calling set_param!($x, $comp_name, $(nameof(param)), $(param.default))"
            set_param!(obj, comp_name, nameof(param), param.default)
        end
    end

    # Return the comp since it's a copy of what was passed in
    return comp_def
end

"""
    add_comp!(obj::CompositeComponentDef, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name,
        exports=nothing, first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the composite component indicated by `obj`. The component
is added at the end of the list unless one of the keywords, `first`, `last`, `before`, `after`. If the
`comp_name` differs from that in the `comp_def`, a copy of `comp_def` is made and assigned the new name.
"""
function add_comp!(obj::AbstractCompositeComponentDef, comp_id::ComponentId,
                   comp_name::Symbol=comp_id.comp_name;
                   exports=nothing,
                   first::NothingInt=nothing, last::NothingInt=nothing,
                   before::NothingSymbol=nothing, after::NothingSymbol=nothing)
    # println("Adding component $comp_id as :$comp_name")
    add_comp!(obj, compdef(comp_id), comp_name,
              exports=exports, first=first, last=last, before=before, after=after)
end

"""
    replace_comp!(obj::CompositeComponentDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        first::NothingInt=nothing, last::NothingInt=nothing,
        before::NothingSymbol=nothing, after::NothingSymbol=nothing,
        reconnect::Bool=true)

Replace the component with name `comp_name` in composite component definition `obj` with the
component `comp_id` using the same name. The component is added in the same position as the
old component, unless one of the keywords `before` or `after` is specified. The component is
added with the same first and last values, unless the keywords `first` or `last` are specified.
Optional boolean argument `reconnect` with default value `true` indicates whether the existing
parameter connections should be maintained in the new component. Returns the added comp def.
"""
function replace_comp!(obj::AbstractCompositeComponentDef, comp_id::ComponentId,
                       comp_name::Symbol=comp_id.comp_name;
                       first::NothingInt=nothing, last::NothingInt=nothing,
                       before::NothingSymbol=nothing, after::NothingSymbol=nothing,
                       reconnect::Bool=true)

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

    # Get original first and last if new run period not specified
    old_comp = compdef(obj, comp_name)
    first = first === nothing ? old_comp.first : first
    last  = last  === nothing ? old_comp.last  : last

    if reconnect
        new_comp = compdef(comp_id)

        function _compare_datum(dict1, dict2)
            set1 = Set([(k, v.datatype, v.dim_names) for (k, v) in dict1])
            set2 = Set([(k, v.datatype, v.dim_names) for (k, v) in dict2])
            return set1 >= set2
        end

        # Check incoming parameters
        incoming_params = map(ipc -> ipc.dst_par_name, internal_param_conns(obj, comp_name))
        old_params = filter(pair -> pair.first in incoming_params, old_comp.parameters)
        new_params = new_comp.parameters
        if !_compare_datum(new_params, old_params)
            error("Cannot replace and reconnect; new component does not contain the necessary parameters.")
        end

        # Check outgoing variables
        _get_name(obj, name) = nameof(compdef(obj, :first))
        outgoing_vars = map(ipc -> ipc.src_var_name,
                            filter(ipc -> nameof(compdef(obj, ipc.src_comp_path)) == comp_name, internal_param_conns(obj)))
        old_vars = filter(pair -> pair.first in outgoing_vars, old_comp.variables)
        new_vars = new_comp.variables
        if !_compare_datum(new_vars, old_vars)
            error("Cannot replace and reconnect; new component does not contain the necessary variables.")
        end

        # Check external parameter connections
        remove = []
        for epc in external_param_conns(obj, comp_name)
            param_name = epc.param_name
            if ! haskey(new_params, param_name)  # TODO: is this the behavior we want? don't error in this case? just (warn)?
                @warn "Removing external parameter connection from component $comp_name; parameter $param_name no longer exists in component."
                push!(remove, epc)
            else
                old_p = old_comp.parameters[param_name]
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

        # Delete the old component from comps_dict, leaving the existing parameter connections
        delete!(obj.comps_dict, comp_name)
    else
        # Delete the old component and all its internal and external parameter connections
        delete!(obj, comp_name)
    end

    # Re-add
    return add_comp!(obj, comp_id, comp_name; first=first, last=last, before=before, after=after)
end
