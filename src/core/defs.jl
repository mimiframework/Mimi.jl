# Global component registry: @defcomp stores component definitions here
global const _compdefs = Dict{ComponentId, ComponentDef}()

compdefs() = collect(values(_compdefs))

compdef(comp_id::ComponentId) = _compdefs[comp_id]

function compdef(comp_name::Symbol)
    matches = collect(Iterators.filter(obj -> nameof(obj) == comp_name, values(_compdefs)))
    count = length(matches)

    if count == 1
        return matches[1]
    elseif count == 0
        error("Component $comp_name was not found in the global registry")
    else
        error("Multiple components named $comp_name were found in the global registry")
    end
end

# Allows method to be called on leaf component defs, which sometimes simplifies code.
compdefs(c::ComponentDef) = []

@method compdefs(c::CompositeComponentDef) = values(c.comps_dict)
@method compkeys(c::CompositeComponentDef) = keys(c.comps_dict)
@method hascomp(c::CompositeComponentDef, comp_name::Symbol) = haskey(c.comps_dict, comp_name)
@method compdef(c::CompositeComponentDef, comp_name::Symbol) = c.comps_dict[comp_name]

# Return the module object for the component was defined in
compmodule(comp_id::ComponentId) = comp_id.module_name
compname(comp_id::ComponentId)   = comp_id.comp_name

@method compmodule(obj::ComponentDef) = compmodule(obj.comp_id)
@method compname(obj::ComponentDef)   = compname(obj.comp_id)

function reset_compdefs(reload_builtins=true)
    empty!(_compdefs)

    if reload_builtins
        compdir = joinpath(@__DIR__, "..", "components")
        load_comps(compdir)
    end
end

first_period(comp_def::ComponentDef) = comp_def.first
last_period(comp_def::ComponentDef)  = comp_def.last

function first_period(comp_def::CompositeComponentDef)
    values = filter(!isnothing, [first_period(c) for c in comp_def])
    return length(values) > 0 ? min(values...) : nothing
end

function last_period(comp_def::CompositeComponentDef)
    values = filter(!isnothing, [last_period(c) for c in comp_def])
    return length(values) > 0 ? max(values...) : nothing
end

function first_period(md::ModelDef, comp_def::AbstractComponentDef)
    period = first_period(comp_def)
    return period === nothing ? time_labels(md)[1] : period
end

function last_period(md::ModelDef, comp_def::AbstractComponentDef)
    period = last_period(comp_def)
    return period === nothing ? time_labels(md)[end] : period
end

@delegate compname(dr::DatumReference)   => comp_id
@delegate compmodule(dr::DatumReference) => comp_id

is_variable(dr::DatumReference)  = has_variable(compdef(dr.comp_id), nameof(dr))
is_parameter(dr::DatumReference) = has_parameter(compdef(dr.comp_id), nameof(dr))

number_type(md::ModelDef) = md.number_type

# TBD: should be numcomps()
@method numcomponents(obj::ComponentDef) = 0   # no sub-components
@method numcomponents(obj::CompositeComponentDef) = length(obj.comps_dict)

function dumpcomps()
    for comp in compdefs()
        println("\n$(nameof(comp))")
        for (tag, objs) in ((:Variables, variables(comp)), (:Parameters, parameters(comp)), (:Dimensions, dim_dict(comp)))
            println("  $tag")
            for obj in objs
                println("    $(nameof(obj)) = $obj")
            end
        end
    end
end

"""
    new_comp(comp_id::ComponentId, verbose::Bool=true)

Add an empty `ComponentDef` to the global component registry with the given
`comp_id`. The empty `ComponentDef` must be populated with calls to `addvariable`,
`addparameter`, etc. Use `@defcomposite` to create composite components.
"""
function new_comp(comp_id::ComponentId, verbose::Bool=true)
    if verbose
        if haskey(_compdefs, comp_id)
            @warn "Redefining component $comp_id"
        else
            @info "new component $comp_id"
        end
    end

    comp_def = ComponentDef(comp_id)
    _compdefs[comp_id] = comp_def
    return comp_def
end

"""
    delete!(m::ModelDef, component::Symbol)

Delete a `component` by name from a model definition `m`.
"""
@method function Base.delete!(ccd::CompositeComponentDef, comp_name::Symbol)
    if ! hascomp(ccd, comp_name)
        error("Cannot delete '$comp_name': component does not exist.")
    end

    delete!(ccd.comps_dict, comp_name)

    ipc_filter = x -> x.src_comp_name != comp_name && x.dst_comp_name != comp_name
    filter!(ipc_filter, ccd.internal_param_conns)

    epc_filter = x -> x.comp_name != comp_name
    filter!(epc_filter, ccd.external_param_conns)  
end

#
# Dimensions
#

@method function add_dimension!(comp::ComponentDef, name)
    # generally, we add dimension name with nothing instead of a Dimension instance,
    # but in the case of an Int name, we create the "anonymous" dimension on the fly.
    dim = (name isa Int) ? Dimension(name) : nothing
    comp.dim_dict[Symbol(name)] = dim                         # TBD: test this
end

add_dimension!(comp_id::ComponentId, name) = add_dimension!(compdef(comp_id), name)

@method function dim_names(ccd::CompositeComponentDef)
    dims = OrderedSet{Symbol}()             # use a set to eliminate duplicates
    for cd in compdefs(ccd)
        union!(dims, keys(dim_dict(cd)))    # TBD: test this
    end

    return collect(dims)
end

@method dim_names(comp_def::ComponentDef, datum_name::Symbol) = dim_names(datumdef(comp_def, datum_name))

@method dim_count(def::DatumDef) = length(dim_names(def))

function step_size(values::Vector{Int})
    return length(values) > 1 ? values[2] - values[1] : 1
end

#
# TBD: should these be defined as @method of CompositeComponentDef
#
function step_size(md::ModelDef)
    keys::Vector{Int} = time_labels(md)
    return step_size(keys)
end

function first_and_step(md::ModelDef)
    keys::Vector{Int} = time_labels(md) # labels are the first times of the model runs
    return first_and_step(keys)
end

function first_and_step(values::Vector{Int})
     return values[1], step_size(values)
end

@method first_and_last(obj::ComponentDef) = (obj.first, obj.last)

function time_labels(md::ModelDef)
    keys::Vector{Int} = dim_keys(md, :time)
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
function datum_size(md::ModelDef, comp_def::ComponentDef, datum_name::Symbol)
    dims = dim_names(comp_def, datum_name)
    if dims[1] == :time
        time_length = getspan(md, comp_def)[1]
        rest_dims = filter(x->x!=:time, dims)
        datum_size = (time_length, dim_counts(md, rest_dims)...,)
    else
        datum_size = (dim_counts(md, dims)...,)
    end
    return datum_size
end

# Symbols are added to the dim_dict in @defcomp (with value of nothing), but are set later using set_dimension!
@method has_dim(obj::CompositeComponentDef, name::Symbol) = (haskey(obj.dim_dict, name) && obj.dim_dict[name] !== nothing)

@method isuniform(obj::CompositeComponentDef) = obj.is_uniform

@method set_uniform!(obj::CompositeComponentDef, value::Bool) = (obj.is_uniform = value)

@method dimension(obj::CompositeComponentDef, name::Symbol) = obj.dim_dict[name]

dim_names(md::ModelDef, dims::Vector{Symbol}) = [dimension(md, dim) for dim in dims]

dim_count_dict(md::ModelDef) = Dict([name => length(value) for (name, value) in dim_dict(md)])
dim_counts(md::ModelDef, dims::Vector{Symbol}) = [length(dim) for dim in dim_names(md, dims)]
dim_count(md::ModelDef, name::Symbol) = length(dimension(md, name))

dim_keys(md::ModelDef, name::Symbol)   = collect(keys(dimension(md, name)))
dim_values(md::ModelDef, name::Symbol) = collect(values(dimension(md, name)))

# For debugging only
@method function _show_run_period(obj::ComponentDef, first, last)
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
@method function set_run_period!(obj::ComponentDef, first, last)
    #_show_run_period(obj, first, last)
    first_per = first_period(obj)
    last_per  = last_period(obj)

    if first_per !== nothing && first_per < first 
        @warn "Resetting $(nameof(comp_def)) component's first timestep to $first"
        obj.first = first
    end 

    if last_per !== nothing && last_per > last 
        @warn "Resetting $(nameof(comp_def)) component's last timestep to $last"
        obj.last = last
    end

    # N.B. compdefs() returns an empty list for leaf ComponentDefs
    for subcomp in compdefs(obj)
        set_run_period!(subcomp, first, last)
    end
    
    nothing
end
 
"""
    set_dimension!(md::CompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange}) 

Set the values of `md` dimension `name` to integers 1 through `count`, if `keys` is
an integer; or to the values in the vector or range if `keys` is either of those types.
"""
@method function set_dimension!(ccd::CompositeComponentDef, name::Symbol, keys::Union{Int, Vector, Tuple, AbstractRange})
    redefined = has_dim(ccd, name)
    if redefined
        @warn "Redefining dimension :$name"
    end

    if name == :time
        set_uniform!(ccd, isuniform(keys))
        set_run_period!(ccd, keys[1], keys[end])
    end
    
    return set_dimension!(ccd, name, Dimension(keys))
end

@method function set_dimension!(obj::CompositeComponentDef, name::Symbol, dim::Dimension)
    obj.dim_dict[name] = dim
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
@method dim_names(obj::DatumDef) = obj.dim_names

@method function addparameter(comp_def::ComponentDef, name, datatype, dimensions, description, unit, default)
    p = ParameterDef(name, datatype, dimensions, description, unit, default)
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
@method parameters(obj::ComponentDef) = values(obj.parameters)

@method function parameters(ccd::CompositeComponentDef)
    pars = ccd.parameters

    # return cached parameters, if any
    if length(pars) == 0
        for (dr, name) in ccd.exports
            cd = compdef(dr.comp_id)
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

@method parameters(obj::DatumReference) = parameters(obj.comp_id)

"""
    parameter_names(md::ModelDef, comp_name::Symbol)

Return a list of all parameter names for a given component `comp_name` in a model def `md`.
"""
parameter_names(md::ModelDef, comp_name::Symbol) = parameter_names(compdef(md, comp_name))

#parameter_names(comp_def::ComponentDef) = [nameof(param) for param in parameters(comp_def)]
@method parameter_names(comp_def::ComponentDef) = collect(keys(comp_def.parameters))

@method parameter(obj::CompositeComponentDef, comp_name::Symbol, param_name::Symbol) = parameter(compdef(obj, comp_name), param_name)

@method parameter(dr::DatumReference) = parameter(compdef(dr.comp_id), nameof(dr))

@method function parameter(obj::ComponentDef, name::Symbol)
    try
        return obj.parameters[name]
    catch
        error("Parameter $name was not found in component $(nameof(obj))")
    end
end

@method has_parameter(comp_def::ComponentDef, name::Symbol) = haskey(comp_def.parameters, name)

@method function parameter_unit(obj::ComponentDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(obj, comp_name, param_name)
    return param.unit
end

@method function parameter_dimensions(obj::ComponentDef, comp_name::Symbol, param_name::Symbol)
    param = parameter(obj, comp_name, param_name)
    return dim_names(param)
end

"""
    set_param!(m::ModelDef, comp_name::Symbol, name::Symbol, value, dims=nothing)

Set the parameter `name` of a component `comp_name` in a model `m` to a given `value`. The
`value` can by a scalar, an array, or a NamedAray. Optional argument 'dims' is a 
list of the dimension names of the provided data, and will be used to check that 
they match the model's index labels.
"""
function set_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, value, dims=nothing)
    # perform possible dimension and labels checks
    if value isa NamedArray
        dims = dimnames(value)
    end

    if dims !== nothing
        check_parameter_dimensions(md, value, dims, param_name)
    end

    comp_param_dims = parameter_dimensions(md, comp_name, param_name)
    num_dims = length(comp_param_dims)
    
    comp_def = compdef(md, comp_name)
    param  = parameter(comp_def, param_name)
    data_type = param.datatype
    dtype = data_type == Number ? number_type(md) : data_type

    if length(comp_param_dims) > 0
        # convert the number type and, if NamedArray, convert to Array
        if dtype <: AbstractArray
            value = convert(dtype, value)
        else
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
                    stepsize = step_size(md)
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
@method variables(comp_def::ComponentDef) = values(comp_def.variables)

@method function variables(ccd::CompositeComponentDef)
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

variables(dr::DatumReference) = variables(dr.comp_id)

@method function variable(comp_def::ComponentDef, var_name::Symbol)
    if is_composite(comp_def)
        variables(comp_def)  # make sure values have been gathered
    end

    try
        return comp_def.variables[var_name]
    catch
        error("Variable $var_name was not found in component $(comp_def.comp_id)")
    end
end

variable(comp_id::ComponentId, var_name::Symbol) = variable(compdef(comp_id), var_name)

variable(md::ModelDef, comp_name::Symbol, var_name::Symbol) = variable(compdef(md, comp_name), var_name)

variable(dr::DatumReference) = variable(compdef(dr.comp_id), nameof(dr))

@method has_variable(comp_def::ComponentDef, name::Symbol) = haskey(comp_def.variables, name)

"""
    variable_names(md::ModelDef, comp_name::Symbol)

Return a list of all variable names for a given component `comp_name` in a model def `md`.
"""
variable_names(md::ModelDef, comp_name::Symbol) = variable_names(compdef(md, comp_name))

variable_names(comp_def::ComponentDef) = [nameof(var) for var in variables(comp_def)]


function variable_unit(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
    return var.unit
end

function variable_dimensions(md::ModelDef, comp_name::Symbol, var_name::Symbol)
    var = variable(md, comp_name, var_name)
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
    addvariables(obj::CompositeComponentDef, exports::Vector{Pair{DatumReference, Symbol}})

Add all exported variables to a CompositeComponentDef.
"""
@method function addvariables(obj::CompositeComponentDef, exports::Vector{Pair{DatumReference, Symbol}})
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
@method function getspan(obj::CompositeComponentDef, comp_name::Symbol)
    comp_def = compdef(obj, comp_name)
    return getspan(obj, comp_def)
end

@method function getspan(obj::CompositeComponentDef, comp_def::ComponentDef)
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
const NothingInt    = Union{Nothing, Int}
const NothingSymbol = Union{Nothing, Symbol}

@method function _append_comp!(obj::CompositeComponentDef, comp_name::Symbol, comp_def::AbstractComponentDef)
   obj.comps_dict[comp_name] = comp_def
end

function _add_anonymous_dims!(md::ModelDef, comp_def::AbstractComponentDef)
    for (name, dim) in filter(pair -> pair[2] !== nothing, comp_def.dim_dict)
        # @info "Setting dimension $name to $dim"
        set_dimension!(md, name, dim)
    end
end

@method function comps_dict!(obj::CompositeComponentDef, comps::OrderedDict{Symbol, AbstractComponentDef})
    obj.comps_dict = comps
end

"""
    add_comp!(md::ModelDef, comp_def::ComponentDef; first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_def` to the composite components indicated by `obj`. The component 
is added at the end of the list unless one of the keywords, `first`, `last`, `before`, `after`. If the 
`comp_name` differs from that in the `comp_def`, a copy of `comp_def` is made and assigned the new name.
"""
@method function add_comp!(obj::CompositeComponentDef, comp_def::AbstractComponentDef, comp_name::Symbol;
                           first::NothingInt=nothing, last::NothingInt=nothing, 
                           before::NothingSymbol=nothing, after::NothingSymbol=nothing)

    # check that a time dimension has been set
    if ! has_dim(obj, :time)
        error("Cannot add component to model without first setting time dimension.")
    end
    
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

    # Check if component being added already exists
    if hascomp(obj, comp_name)
        error("Cannot add two components of the same name ($comp_name)")
    end

    # Create a deepcopy of the original but with the new name so
    # it has separate variables and parameters, etc.
    if compname(comp_def.comp_id) != comp_name
        comp_def = copy_comp_def(comp_def, comp_name)
    end        

    set_run_period!(comp_def, first, last)

    _add_anonymous_dims!(obj, comp_def)

    if before === nothing && after === nothing
        _append_comp!(obj, comp_name, comp_def)   # just add it to the end
    else
        new_comps = OrderedDict{Symbol, AbstractComponentDef}()

        if before !== nothing
            if ! hascomp(obj, before)
                error("Component to add before ($before) does not exist")
            end

            for k in compkeys(obj)
                if k == before
                    new_comps[comp_name] = comp_def
                end
                new_comps[k] = compdef(obj, k)
            end

        else    # after !== nothing, since we've handled all other possibilities above
            if ! hascomp(obj, after)
                error("Component to add before ($before) does not exist")
            end

            for k in compkeys(obj)
                new_comps[k] = compdef(obj, k)
                if k == after
                    new_comps[comp_name] = comp_def
                end
            end
        end

        comps_dict!(obj, new_comps)
        # println("obj.comp_defs: $(comp_defs(obj))")
    end

    # Set parameters to any specified defaults
    for param in parameters(comp_def)
        if param.default !== nothing
            set_param!(obj, comp_name, nameof(param), param.default)
        end
    end
    
    return nothing
end

"""
    add_comp!(obj::CompositeComponentDef, comp_id::ComponentId; comp_name::Symbol=comp_id.comp_name, 
        first=nothing, last=nothing, before=nothing, after=nothing)

Add the component indicated by `comp_id` to the composite component indicated by `obj`. The component 
is added at the end of the list unless one of the keywords, `first`, `last`, `before`, `after`. If the 
`comp_name` differs from that in the `comp_def`, a copy of `comp_def` is made and assigned the new name.
"""
@method function add_comp!(obj::CompositeComponentDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                           first::NothingInt=nothing, last::NothingInt=nothing, 
                           before::NothingSymbol=nothing, after::NothingSymbol=nothing)
    # println("Adding component $comp_id as :$comp_name")
    add_comp!(obj, compdef(comp_id), comp_name, first=first, last=last, before=before, after=after)
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
parameter connections should be maintained in the new component.
"""
@method function replace_comp!(obj::CompositeComponentDef, comp_id::ComponentId, comp_name::Symbol=comp_id.comp_name;
                               first::NothingInt=nothing, last::NothingInt=nothing,
                               before::NothingSymbol=nothing, after::NothingSymbol=nothing,
                               reconnect::Bool=true)

    if ! hascomp(obj, comp_name)
        error("Cannot replace '$comp_name'; component not found in model.")
    end

    # Get original position if new before or after not specified
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
    last = last === nothing ? old_comp.last : last

    if reconnect
        # Assert that new component definition has same parameters and variables needed for the connections

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
            error("Cannot replace and reconnect; new component does not contain the same definitions of necessary parameters.")
        end
        
        # Check outgoing variables
        outgoing_vars = map(ipc -> ipc.src_var_name, filter(ipc -> ipc.src_comp_name == comp_name, internal_param_conns(obj)))
        old_vars = filter(pair -> pair.first in outgoing_vars, old_comp.variables)
        new_vars = new_comp.variables
        if !_compare_datum(new_vars, old_vars)
            error("Cannot replace and reconnect; new component does not contain the same definitions of necessary variables.")
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
    add_comp!(obj, comp_id, comp_name; first=first, last=last, before=before, after=after)
end

"""
    copy_comp_def(comp_def::ComponentDef, comp_name::Symbol)

Copy the given `comp_def`, naming the copy `comp_name`.
"""
function copy_comp_def(comp_def::ComponentDef, comp_name::Symbol)
    obj  = deepcopy(comp_def)
    obj.name = comp_name
    return obj
end
