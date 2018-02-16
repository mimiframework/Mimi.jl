"""
Removes any parameter connections for a given parameter in a given component.
"""
function disconnect(m::Model, comp_name::Symbol, parameter::Symbol)
    filter!(x -> !(x.target_comp_name == comp_name && x.target_parameter_name == parameter), m.internal_parameter_connections)
    filter!(x -> !(x.component_name == comp_name && x.param_name == parameter), m.external_parameter_connections)
end

"""
    connectparameter(m::Model, component::Symbol, name::Symbol, parametername::Symbol)

Connect a parameter in a component to an external parameter.
"""
function connectparameter(m::Model, comp_name::Symbol, param_name::Symbol, ext_param_name::Symbol)
    ext_param = external_parameter(m, ext_param_name)

    if isa(p, ArrayModelParameter)
        checklabels(m, comp_name, param_name, ext_param)
    end

    disconnect(m, comp_name, param_name)

    conn = ExternalParameterConnection(comp_name, param_name, ext_param_name)
    push!(m.external_parameter_connections, conn)

    nothing
end

function checklabels(m::Model, comp_name::Symbol, param_name::Symbol, ext_param::ArrayModelParameter)
    param_def = parameter(m, comp_name, param_name)
    if ! (eltype(ext_param.values) <: param_def.datatype)
        error("Mismatched datatype of parameter connection. Component: $comp_name, Parameter: $param_name")
    end

    comp_dims = param_def.dimensions

    if ! isempty(ext_param.dims) && size(ext_param.dims) != size(comp_dims)
        error("Mismatched dimensions of parameter connection. Component: $comp_name, Parameter: $param_name")
    end

    # Don't check sizes for ConnectorComps since they won't match.
    if comp_name in (:ConnectorCompVector, :ConnectorCompMatrix)
        return nothing
    end

    for (i, dim) in enumerate(comp_dims)
        if isa(dim, Symbol) 
            if length(indexvalue(m, dim) != size(ext_param.values)[i])
                error("Mismatched data size for a parameter connection. Component: $component, Parameter: $param_name")
            end
        end
    end
end

"""
    connectparameter(m::Model, target_component::Symbol, target_name::Symbol, source_component::Symbol, source_name::Symbol; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connectparameter(m::Model, target_comp_id::ComponentId, target_param::Symbol, 
                          source_comp_id::ComponentId, source_var::Symbol; ignoreunits::Bool=false)

    target_comp_def = compdef(target_comp_id)
    source_comp_def = compdef(source_comp_id)

    # Check the units, if provided
    if !ignoreunits && !unitcheck(target_comp_def.parameters[target_param].unit, source_comp_def.variables[source_var].unit)
        error("Units of $source_component.$source_var do not match $target_component.$target_param.")
    end

    # remove any existing connections for this target component and parameter
    disconnect(m, target_comp_id, target_param)

    curr = InternalParameterConnection(source_var, source_comp_id, target_param, target_comp_id, ignoreunits)
    # push!(m.internal_parameter_connections, curr)
    add_internal_parameter_conn(m, curr)

    nothing
end

"""
    connectparameter(m::Model, target::Pair{Symbol, Symbol}, source::Pair{Symbol, Symbol}; ignoreunits::Bool=false)

Bind the parameter of one component to a variable in another component.
"""
function connectparameter(m::Model, target::Pair{ComponentId, Symbol}, source::Pair{ComponentId, Symbol}; 
                          ignoreunits::Bool=false)
    connectparameter(m, target[1], target[2], source[1], source[2]; ignoreunits=ignoreunits)
end

function connectparameter(m::Model, target::Pair{ComponentId, Symbol}, source::Pair{ComponentId, Symbol}, 
                          backup::Array; ignoreunits::Bool=false)
    connectparameter(m, target[1], target[2], source[1], source[2], backup; ignoreunits=ignoreunits)
end

function connectparameter(m::Model, target_comp_id::ComponentId, target_param::Symbol, 
                          source_comp_id::ComponentId, source_var::Symbol, backup::Array; ignoreunits::Bool=false)
    # If value is a NamedArray, we can check if the labels match
    if isa(backup, NamedArray)
        dims = dimnames(backup)
        check_parameter_dimensions(m, backup, dims, name)       # TBD: What should name be here?
    else
        dims = nothing
    end

    # Check that the backup value is the right size
    if getspan(m, target_component) != size(backup)[1]
        error("Backup data must span the whole length of the component.")
    end

    # some other check for second dimension??

    comp_param_dims = getmetainfo(m, target_component).parameters[target_param].dimensions
    backup = convert(Array{m.numberType}, backup) # converts the number type, and also if it's a NamedArray it gets converted to Array
    offset = m.components2[target_component].offset
    duration = getduration(m)
    T = eltype(backup)

    dim_count = length(comp_param_dims)

    if dim_count in (1, 2)
        ts_type = dim_count == 1 ? TimestepVector : TimestepMatrix
        values = ts_type{T, offset, duration}(backup)
    else
        values = backup
    end

    set_external_array_parameter(m, target_param, values, dims)

    target_comp_def = compdef(target_comp_id)
    source_comp_def = compdef(source_comp_id)

    # Check the units, if provided
    if !ignoreunits && !unitcheck(target_comp_def.parameters[target_param].unit, source_comp_def.variables[source_var].unit)
        error("Units of $source_component.$source_var do not match $target_component.$target_param.")
    end

    # remove any existing connections for this target component and parameter
    disconnect(m, target_comp_id, target_param)

    curr = InternalParameterConnection(source_var, source_comp_id, target_param, target_comp_id, ignoreunits, target_param)
    push!(m.internal_parameter_connections, curr)

    nothing
end

# Default string, string unit check function
function unitcheck(one::AbstractString, two::AbstractString)
    # True if and only if they match
    return one == two
end
