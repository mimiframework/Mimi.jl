compdef(comp_id::ComponentId) = getfield(getfield(Main, comp_id.module_name), comp_id.comp_name)

compdefs(md::ModelDef) = values(md.comp_defs)

compkeys(md::ModelDef) = keys(md.comp_defs)

hascomp(md::ModelDef, comp_name::Symbol) = haskey(md.comp_defs, comp_name)

compdef(md::ModelDef, comp_name::Symbol) = md.comp_defs[comp_name]

function reset_compdefs(reload_builtins=true)
    if reload_builtins
        compdir = joinpath(@__DIR__, "..", "components")
        load_comps(compdir)
    end
end

first_period(comp_def::ComponentDef) = comp_def.first
first_period(md::ModelDef, comp_def::ComponentDef) = first_period(comp_def) === nothing ? time_labels(md)[1] : first_period(comp_def)

last_period(comp_def::ComponentDef) = comp_def.last
last_period(md::ModelDef, comp_def::ComponentDef) = last_period(comp_def) === nothing ? time_labels(md)[end] : last_period(comp_def)

# Return the module object for the component was defined in
compmodule(comp_id::ComponentId) = comp_id.module_name
compname(comp_id::ComponentId) = comp_id.comp_name

compmodule(comp_def::ComponentDef) = compmodule(comp_def.comp_id)
compname(comp_def::ComponentDef) = compname(comp_def.comp_id)


function Base.show(io::IO, comp_id::ComponentId)
    print(io, "<ComponentId $(comp_id.module_name).$(comp_id.comp_name)>")
end

"""
    name(def::NamedDef) = def.name 

Return the name of `def`.  Possible `NamedDef`s include `DatumDef`, and `ComponentDef`.
"""
name(def::NamedDef) = def.name

number_type(md::ModelDef) = md.number_type

numcomponents(md::ModelDef) = length(md.comp_defs)

"""
    delete!(m::ModelDef, component::Symbol

Delete a `component` by name from a model definition `m`.
"""
function Base.delete!(md::ModelDef, comp_name::Symbol)
    if ! haskey(md.comp_defs, comp_name)
        error("Cannot delete '$comp_name' from model; component does not exist.")
    end

    delete!(md.comp_defs, comp_name)

    ipc_filter = x -> x.src_comp_name != comp_name && x.dst_comp_name != comp_name
    filter!(ipc_filter, md.internal_param_conns)

    epc_filter = x -> x.comp_name != comp_name
    filter!(epc_filter, md.external_param_conns)  
end

#
# Dimensions
#
"""
    add_dimension!(comp::ComponentDef, name)

Add a dimension name to a `ComponentDef`, with an optional Dimension definition.
The definition is included only for the case of anonymous dimensions, which are 
indicated in `@defcomp` with an Int rather than a symbol name. In this case, the
Int (e.g., 4) is converted to a dimension of the same length, e.g., `Dimension(4)`,
and assigned a new name `Symbol(4)``
"""
function add_dimension!(comp::ComponentDef, name)
    # create the Dimension and store it in the ComponentDef until build time
    dim = (name isa Int) ? Dimension(name) : nothing
    comp.dimensions[Symbol(name)] = dim
end

add_dimension!(comp_id::ComponentId, name) = add_dimension!(compdef(comp_id), name)

dimensions(comp_def::ComponentDef) = keys(comp_def.dimensions)

dimensions(def::DatumDef) = def.dimensions

dimensions(comp_def::ComponentDef, datum_name::Symbol) = dimensions(datumdef(comp_def, datum_name))

dim_count(def::DatumDef) = length(def.dimensions)

datatype(def::DatumDef) = def.datatype

description(def::DatumDef) = def.description

unit(def::DatumDef) = def.unit

function first_and_step(md::ModelDef)
    keys::Vector{Int} = time_labels(md) # labels are the first times of the model runs
    return first_and_step(keys)
end

function first_and_step(values::Vector{Int})
     return values[1], (length(values) > 1 ? values[2] - values[1] : 1)
end

function time_labels(md::ModelDef)
    keys::Vector{Int} = dim_keys(md, :time)
    return keys
end

function check_parameter_dimensions(md::ModelDef, value::AbstractArray, dims::Vector, name::Symbol)
    for dim in dims
        if haskey(md, dim)
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

function datum_size(md::ModelDef, comp_def::ComponentDef, datum_name::Symbol)
    dims = dimensions(comp_def, datum_name)
    if dims[1] == :time
        time_length = getspan(md, comp_def)[1]
        rest_dims = filter(x->x!=:time, dims)
        datum_size = (time_length, dim_counts(md, rest_dims)...,)
    else
        datum_size = (dim_counts(md, dims)...,)
    end
    return datum_size
end


dimensions(md::ModelDef) = md.dimensions
dimensions(md::ModelDef, dims::Vector{Symbol}) = [dimension(md, dim) for dim in dims]
dimension(md::ModelDef, name::Symbol) = md.dimensions[name]

dim_count_dict(md::ModelDef) = Dict([name => length(value) for (name, value) in dimensions(md)])
dim_counts(md::ModelDef, dims::Vector{Symbol}) = [length(dim) for dim in dimensions(md, dims)]

"""
    dim_count(md::ModelDef, name::Symbol)

Return the size of index `name` in model definition `md`.
"""
dim_count(md::ModelDef, name::Symbol) = length(dimension(md, name))

"""
    dim_key_dict(md::ModelDef)

Return a dict of dimension keys for all dimensions in model definition `md`.
"""
dim_key_dict(md::ModelDef) = Dict([name => collect(keys(dim)) for (name, dim) in dimensions(md)])
"""
    dim_keys(md::ModelDef, name::Symbol)
    
Return keys for dimension `name` in model definition `md`.
"""
dim_keys(md::ModelDef, name::Symbol) = collect(keys(dimension(md, name)))

dim_values(md::ModelDef, name::Symbol) = collect(values(dimension(md, name)))
dim_value_dict(md::ModelDef) = Dict([name => collect(values(dim)) for (name, dim) in dimensions(md)])

Base.haskey(md::ModelDef, name::Symbol) = haskey(md.dimensions, name)

isuniform(md::ModelDef) = md.is_uniform


# Helper function invoked when the user resets the time dimension with set_dimension!
# This function calls set_run_period! on each component definition to reset the first and last values.
function reset_run_periods!(md, first, last)
    for comp_def in compdefs(md)
        changed = false
        first_per = first_period(comp_def)
        last_per  = last_period(comp_def)

        if first_per !== nothing && first_per < first 
            @debug "Resetting $(comp_def.name) component's first timestep to $first"
            changed = true
        else
            first = first_per
        end 

        if last_per !== nothing && last_per > last 
            @debug "Resetting $(comp_def.name) component's last timestep to $last"
            changed = true
        else 
            last = last_per
        end

        if changed
            set_run_period!(comp_def, first, last)
        end
    end
    nothing
end
 
"""
    set_dimension!(md::ModelDef, name::Symbol, keys::Union{Int, Vector, Tuple, Range}) 

Set the values of `md` dimension `name` to integers 1 through `count`, if `keys` is
an integer; or to the values in the vector or range if `keys` is either of those types.
"""
set_dimension!(md::ModelDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange}) = set_dimension!(md, name, Dimension(keys))

function set_dimension!(md::ModelDef, name::Symbol, dim::Dimension)
    redefined = haskey(md, name)
    if redefined
        @debug "Redefining dimension :$name"
    end

    if name == :time
        k = [keys(dim)...]
        md.is_uniform = isuniform(k)
        if redefined 
            reset_run_periods!(md, k[1], k[end])
        end
    end
    
    md.dimensions[name] = dim
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

#needed when time dimension is defined using a single integer
function isuniform(values::Int)
    return true
end

# function isuniform(values::AbstractRange{Int})
#     return isuniform(collect(values))
# end

#
# Parameters
#

external_params(md::ModelDef) = md.external_params

function addparameter(comp_def::ComponentDef, name, datatype, dimensions, description, unit, default)
    p = DatumDef(name, datatype, dimensions, description, unit, :parameter, default)
    comp_def.parameters[name] = p
    return p
end

function addparameter(comp_id::ComponentId, name, datatype, dimensions, description, unit, default)
    addparameter(compdef(comp_id), name, datatype, dimensions, description, unit, default)
end

"""
    parameters(comp_def::ComponentDef)

Return a list of the parameter definitions for `comp_def`.
"""
parameters(comp_def::ComponentDef) = values(comp_def.parameters)

"""
    parameters(comp_id::ComponentDef)

Return a list of the parameter definitions for `comp_id`.
"""
parameters(comp_id::ComponentId) = parameters(compdef(comp_id))

"""
    parameter_names(md::ModelDef, comp_name::Symbol)

Return a list of all parameter names for a given component `comp_name` in a model def `md`.
"""
parameter_names(md::ModelDef, comp_name::Symbol) = parameter_names(compdef(md, comp_name))

parameter_names(comp_def::ComponentDef) = [name(param) for param in parameters(comp_def)]

parameter(md::ModelDef, comp_name::Symbol, param_name::Symbol) = parameter(compdef(md, comp_name), param_name)

function parameter(comp_def::ComponentDef, name::Symbol) 
    try
        return comp_def.parameters[name]
    catch
        error("Parameter $name was not found in component $(comp_def.name)")
    end
end

function parameter_unit(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(md, comp_name, param_name)
    return param.unit
end

"""
    parameter_dimensions(md::ModelDef, comp_name::Symbol, param_name::Symbol)

Return a vector of the dimensions of `param_name` in component `comp_name` in model `md`
"""
function parameter_dimensions(md::ModelDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(md, comp_name, param_name)
    return param.dimensions
end

"""
    set_param!(m::ModelDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter `name` of a component `comp_name` in a model `m` to a given `value`. The
`value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' is a 
list of the dimension names ofthe provided data, and will be used to check that 
they match the model's index labels.
"""
function set_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    # perform possible dimension and labels checks
    if isa(value, NamedArray)
        dims = dimnames(value)
    end

    if dims !== nothing
        check_parameter_dimensions(md, value, dims, param_name)
    end

    comp_param_dims = parameter_dimensions(md, comp_name, param_name)
    num_dims = length(comp_param_dims)

    comp_def = compdef(md, comp_name)
    data_type = datatype(parameter(comp_def, param_name))
    dtype = data_type == Number ? number_type(md) : data_type

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
                first = first_period(md, comp_def)

                if isuniform(md)
                    _, stepsize = first_and_step(md)
                    values = TimestepArray{FixedTimestep{first, stepsize}, T, num_dims}(value)
                else
                    times = time_labels(md)  
                    #use the first from the comp_def 
                    first_index = findfirst(isequal(first), times)                
                    values = TimestepArray{VariableTimestep{(times[first_index:end]...,)}, T, num_dims}(value)
                end 
            end
        else
            values = value
        end

        set_external_array_param!(md, param_name, values, comp_param_dims)

    else # scalar parameter case
        value = convert(dtype, value)
        set_external_scalar_param!(md, param_name, value)
    end

    connect_param!(md, comp_name, param_name, param_name)
    nothing
end

#
# Variables
#
variables(comp_def::ComponentDef) = values(comp_def.variables)

variables(comp_id::ComponentId) = variables(compdef(comp_id))

function variable(comp_def::ComponentDef, var_name::Symbol)
    try
        return comp_def.variables[var_name]
    catch
        error("Variable $var_name was not found in component $(comp_def.comp_id)")
    end
end

variable(comp_id::ComponentId, var_name::Symbol) = variable(compdef(comp_id), var_name)

variable(md::ModelDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(md, comp_name), var_name)

"""
    variable_names(md::ModelDef, comp_name::Symbol)

Return a list of all variable names for a given component `comp_name` in a model def `md`.
"""
variable_names(md::ModelDef, comp_name::Symbol) = variable_names(compdef(md, comp_name))

variable_names(comp_def::ComponentDef) = [name(var) for var in variables(comp_def)]


function variable_unit(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
    return var.unit
end

"""
    parameter_dimensions(md::ModelDef, comp_name::Symbol, param_name::Symbol)

Return a vector of the dimensions of `var_name` in component `comp_name` in model `md`
"""
function variable_dimensions(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
    return var.dimensions
end

# Add a variable to a ComponentDef
function addvariable(comp_def::ComponentDef, name, datatype, dimensions, description, unit)
    v = DatumDef(name, datatype, dimensions, description, unit, :variable)
    comp_def.variables[name] = v
    return v
end

# Add a variable to a ComponentDef referenced by ComponentId
function addvariable(comp_id::ComponentId, name, datatype, dimensions, description, unit)
    addvariable(compdef(comp_id), name, datatype, dimensions, description, unit)
end

#
# Other
#

# Return the number of timesteps a given component in a model will run for.
function getspan(md::ModelDef, comp_name::Symbol)
    comp_def = compdef(md, comp_name)
    return getspan(md, comp_def)
end

function getspan(md::ModelDef, comp_def::ComponentDef)
    first = first_period(md, comp_def)
    last  = last_period(md, comp_def)
    times = time_labels(md)
    first_index = findfirst(isequal(first), times)
    last_index  = findfirst(isequal(last), times)
    return size(times[first_index:last_index])
end

function set_run_period!(comp_def::ComponentDef, first, last)
    comp_def.first = first
    comp_def.last = last
    return nothing
end

#
# Model
#
const NothingInt    = Union{Nothing, Int}
const NothingSymbol = Union{Nothing, Symbol}

function _add_anonymous_dims!(md::ModelDef, comp_def::ComponentDef)
    for (name, dim) in filter(pair -> pair[2] !== nothing, comp_def.dimensions)
        # @info "Setting dimension $name to $dim"
        set_dimension!(md, name, dim)
    end
end

"""
    add_comp!(md::ModelDef, comp_def::ComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name; 
              first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_def` to the model indcated by `md`. The component is added at the 
end of the list unless one of the keywords, `first`, `last`, `before`, `after`. If the `comp_name`
differs from that in the `comp_def`, a copy of `comp_def` is made and assigned the new name.
"""
function add_comp!(md::ModelDef, comp_def::ComponentDef, comp_name::Symbol=comp_def.comp_id.comp_name;
                   first::NothingInt=nothing, last::NothingInt=nothing, 
                   before::NothingSymbol=nothing, after::NothingSymbol=nothing)

    # check that a time dimension has been set
    if !haskey(dimensions(md), :time)
        error("Cannot add component to model without first setting time dimension.")
    end
    
    # check that first and last are within the model's time index range
    time_index = dim_keys(md, :time)

    if first !== nothing && first < time_index[1]
        error("Cannot add component $name with first time before first of model's time index range.")
    end

    if last !== nothing && last > time_index[end]
        error("Cannot add component $name with last time after end of model's time index range.")
    end

    if before !== nothing && after !== nothing
        error("Cannot specify both 'before' and 'after' parameters")
    end

    # Check if component being added already exists
    if hascomp(md, comp_name)
        error("Cannot add two components of the same name ($comp_name)")
    end

    # Create a shallow copy of the original but with the new name
    # TBD: Why do we need to make a copy here? Sort this out.
    if compname(comp_def.comp_id) != comp_name
        comp_def = copy_comp_def(comp_def, comp_name)
    end        

    set_run_period!(comp_def, first, last)

    _add_anonymous_dims!(md, comp_def)

    if before === nothing && after === nothing
        md.comp_defs[comp_name] = comp_def   # just add it to the end
    else
        new_comps = OrderedDict{Symbol, ComponentDef}()

        if before !== nothing
            if ! hascomp(md, before)
                error("Component to add before ($before) does not exist")
            end

            for i in compkeys(md)
                if i == before
                    new_comps[comp_name] = comp_def
                end
                new_comps[i] = md.comp_defs[i]
            end

        else    # after !== nothing, since we've handled all other possibilities above
            if ! hascomp(md, after)
                error("Component to add before ($before) does not exist")
            end

            for i in compkeys(md)
                new_comps[i] = md.comp_defs[i]
                if i == after
                    new_comps[comp_name] = comp_def
                end
            end
        end

        md.comp_defs = new_comps
        # println("md.comp_defs: $(md.comp_defs)")
    end

    # Set parameters to any specified defaults
    for param in parameters(comp_def)
        if param.default !== nothing
            set_param!(md, comp_name, name(param), param.default)
        end
    end
    
    return nothing
end

"""
    add_comp!(md::ModelDef, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name, 
        first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the model indicated by `md`. The component is added at the end of 
the list unless one of the keywords, `first`, `last`, `before`, `after`. If the `comp_name`
differs from that in the `comp_def`, a copy of `comp_def` is made and assigned the new name.
"""
function add_comp!(md::ModelDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                   first::NothingInt=nothing, last::NothingInt=nothing, 
                   before::NothingSymbol=nothing, after::NothingSymbol=nothing)
    # println("Adding component $comp_id as :$comp_name")
    add_comp!(md, compdef(comp_id), comp_name, first=first, last=last, before=before, after=after)
end

"""
    replace_comp!(md::ModelDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
        first::NothingInt=nothing, last::NothingInt=nothing,
        before::NothingSymbol=nothing, after::NothingSymbol=nothing,
        reconnect::Bool=true)

Replace the component with name `comp_name` in model definition `md` with the 
component `comp_id` using the same name. The component is added in the same 
position as the old component, unless one of the keywords `before` or `after` 
is specified. The component is added with the same first and last values, 
unless the keywords `first` or `last` are specified. Optional boolean argument 
`reconnect` with default value `true` indicates whether the existing parameter 
connections should be maintained in the new component.
"""
function replace_comp!(md::ModelDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                           first::NothingInt=nothing, last::NothingInt=nothing,
                           before::NothingSymbol=nothing, after::NothingSymbol=nothing,
                           reconnect::Bool=true)

    if ! haskey(md.comp_defs, comp_name)
        error("Cannot replace '$comp_name'; component not found in model.")
    end

    # Get original position if new before or after not specified
    if before === nothing && after === nothing
        comps = collect(keys(md.comp_defs))
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
    old_comp = md.comp_defs[comp_name]
    first = first === nothing ? old_comp.first : first
    last = last === nothing ? old_comp.last : last

    if reconnect
        # Assert that new component definition has same parameters and variables needed for the connections

        new_comp = compdef(comp_id)

        function _compare_datum(dict1, dict2)
            set1 = Set([(k, v.datatype, v.dimensions) for (k, v) in dict1])
            set2 = Set([(k, v.datatype, v.dimensions) for (k, v) in dict2])
            return set1 >= set2
        end

        # Check incoming parameters
        incoming_params = map(ipc -> ipc.dst_par_name, internal_param_conns(md, comp_name))
        old_params = filter(pair -> pair.first in incoming_params, old_comp.parameters)
        new_params = new_comp.parameters
        if !_compare_datum(new_params, old_params)
            error("Cannot replace and reconnect; new component does not contain the same definitions of necessary parameters.")
        end
        
        # Check outgoing variables
        outgoing_vars = map(ipc -> ipc.src_var_name, filter(ipc -> ipc.src_comp_name == comp_name, md.internal_param_conns))
        old_vars = filter(pair -> pair.first in outgoing_vars, old_comp.variables)
        new_vars = new_comp.variables
        if !_compare_datum(new_vars, old_vars)
            error("Cannot replace and reconnect; new component does not contain the same definitions of necessary variables.")
        end
        
        # Check external parameter connections
        remove = []
        for epc in external_param_conns(md, comp_name)
            param_name = epc.param_name
            if ! haskey(new_params, param_name)  # TODO: is this the behavior we want? don't error in this case? just (warn)?
                @debug "Removing external parameter connection from component $comp_name; parameter $param_name no longer exists in component."
                push!(remove, epc)
            else
                old_p = old_comp.parameters[param_name]
                new_p = new_params[param_name]
                if new_p.dimensions != old_p.dimensions
                    error("Cannot replace and reconnect; parameter $param_name in new component has different dimensions.")
                end
                if new_p.datatype != old_p.datatype
                    error("Cannot replace and reconnect; parameter $param_name in new component has different datatype.")
                end
            end
        end
        filter!(epc -> !(epc in remove), md.external_param_conns) 

        # Delete the old component from comp_defs, leaving the existing parameter connections 
        delete!(md.comp_defs, comp_name)      
    else
        # Delete the old component and all its internal and external parameter connections
        delete!(md, comp_name)  
    end

    # Re-add
    add_comp!(md, comp_id, comp_name; first=first, last=last, before=before, after=after)

end

"""
    copy_comp_def(comp_def::ComponentDef, comp_name::Symbol)

Create a mostly-shallow copy of `comp_def` (named `comp_name`), but make a deep copy of its
ComponentId so we can rename the copy without affecting the original.
"""
function copy_comp_def(comp_def::ComponentDef, comp_name::Symbol)
    comp_id = comp_def.comp_id
    obj     = ComponentDef(comp_id)

    # Use the comp_id as is, since this identifies the run_timestep function, but
    # use an alternate name to reference it in the model's component list.
    obj.name = comp_name

    obj.variables  = comp_def.variables
    obj.parameters = comp_def.parameters
    obj.dimensions = comp_def.dimensions
    obj.first      = comp_def.first
    obj.last       = comp_def.last

    return obj
end

"""
    copy_external_params(md::ModelDef)

Make copies of ModelParameter subtypes representing external parameters of model `md`. 
This is used both in the copy() function below, and in the simulation subsystem 
to restore values between trials.

"""
function copy_external_params(md::ModelDef)
    external_params = Dict{Symbol, ModelParameter}(key => copy(obj) for (key, obj) in md.external_params)
    return external_params
end

Base.copy(obj::ScalarModelParameter{T}) where T = ScalarModelParameter{T}(copy(obj.value))

Base.copy(obj::ScalarModelParameter{T}) where T <: Union{Symbol, AbstractString} = ScalarModelParameter{T}(obj.value)

Base.copy(obj::ArrayModelParameter{T})  where T = ArrayModelParameter{T}(copy(obj.values), obj.dimensions)

function Base.copy(obj::TimestepVector{T_ts, T}) where {T_ts, T}
    return TimestepVector{T_ts, T}(copy(obj.data))
end

function Base.copy(obj::TimestepMatrix{T_ts, T}) where {T_ts, T}
    return TimestepMatrix{T_ts, T}(copy(obj.data))
end

function Base.copy(obj::TimestepArray{T_ts, T, N}) where {T_ts, T, N}
    return TimestepArray{T_ts, T, N}(copy(obj.data))
end

"""
    copy(md::ModelDef)

Create a copy of a ModelDef `md` object that is not entirely shallow, nor completely deep.
The aim is to copy the full structure, reusing references to immutable elements.
"""
function Base.copy(md::ModelDef)
    mdcopy = ModelDef(md.number_type)
    mdcopy.module_name = md.module_name
    
    merge!(mdcopy.comp_defs, md.comp_defs)
    
    mdcopy.dimensions = deepcopy(md.dimensions)

    # These are vectors of immutable structs, so we can (shallow) copy them safely
    mdcopy.internal_param_conns = copy(md.internal_param_conns)
    mdcopy.external_param_conns = copy(md.external_param_conns)

    # Names of external params that the ConnectorComps will use as their :input2 parameters.
    mdcopy.backups = copy(md.backups)
    mdcopy.external_params = copy_external_params(md)

    mdcopy.sorted_comps = md.sorted_comps === nothing ? nothing : copy(md.sorted_comps)    
    
    mdcopy.is_uniform = md.is_uniform

    return mdcopy
end
