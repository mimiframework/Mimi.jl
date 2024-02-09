"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef, param_name::Symbol)
    # If the path isn't set yet, we look for a comp in the eventual location
    path = @or(comp_def.comp_path, ComponentPath(obj, comp_def.name))

    # @info "disconnect_param!($(obj.comp_path), $path, :$param_name)"

    if is_descendant(obj, comp_def) === nothing
        error("Cannot disconnect a component ($path) that is not within the given composite ($(obj.comp_path))")
    end

    filter!(x -> !(x.dst_comp_path == path && x.dst_par_name == param_name), obj.internal_param_conns)

    if obj isa ModelDef
        
        # if disconnecting an unshared parameter, it will become unreachable since
        # it's name is a random, unique symbol so remove it from the ModelDef's 
        # list of model parameters
        model_param_name = get_model_param_name(obj, nameof(comp_def), param_name; missing_ok = true)
        if !isnothing(model_param_name) && !(model_param(obj, model_param_name).is_shared)
            delete!(obj.model_params, model_param_name);
        end

        filter!(x -> !(x.comp_path == path && x.param_name == param_name), obj.external_param_conns)
    end
    dirty!(obj)
end

"""
    disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)

Remove any parameter connections for a given parameter `param_name` in a given component
`comp_def` which must be a direct subcomponent of composite `obj`.
"""
function disconnect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol)
    comp = compdef(obj, comp_name)
    comp === nothing && error("Did not find $comp_name in composite $(printable(obj.comp_path))")
    disconnect_param!(obj, comp, param_name)
end

# Default string, string unit check function
verify_units(unit1::AbstractString, unit2::AbstractString) = (unit1 == unit2)

"""
    _check_attributes(obj::AbstractCompositeComponentDef,
                comp_def::AbstractComponentDef, param_name::Symbol, 
                mod_param::ArrayModelParameter)

Check that the attributes of the ArrayModelParameter `mod_param` match the attributes
of the model parameter `param_name` in component `comp_def` of object `obj`, 
including datatype and dimensions. 
"""
function _check_attributes(obj::AbstractCompositeComponentDef,
                       comp_def::AbstractComponentDef, param_name::Symbol, mod_param::ArrayModelParameter)

    is_nothing_param(mod_param) && return 

    param_def = parameter(comp_def, param_name)

    # handle string case 
    t1 = eltype(mod_param.values)
    t2 = eltype(param_def.datatype)
    
    # handle String case
    if t1 == Char; t1 = String; end
    if t2 == Char; t2 = String; end

    if !(t1 <: Union{Missing, t2})
        error("Mismatched datatype of parameter connection: Component: $(nameof(comp_def)) ",
        "Parameter: $param_name ($t2) to Model Parameter ($t1). Mimi requires that ",
        "the model parameter type be a subtype of the component parameter type (Unioned with Missing for arrays) ",
        "($t1 <: Union{Missing, $t2}) If you are using `add_shared_param!` try ",
        "using the `data_type` keyword argument to specifiy data_type = $(eltype(param_def.datatype))")
    end

    param_dims = dim_names(param_def)
    model_dims = dim_names(mod_param)

    if ! isempty(param_dims) && size(param_dims) != size(model_dims)
        d1 = size(model_dims)
        d2 = size(param_dims)
        error("Mismatched dimensions of parameter connection: Component: $(nameof(comp_def)) Parameter: $param_name (size $d2) to Model Parameter (size $d1)")
    end

    # Don't check sizes for ConnectorComps since they won't match.
    if nameof(comp_def) in (:ConnectorCompVector, :ConnectorCompMatrix)
        return nothing
    end

    # index_values = indexvalues(obj)

    for (i, dim) in enumerate(param_dims)
        if isa(dim, Symbol)
            param_length = size(mod_param.values)[i]
            comp_length = dim_count(obj, dim)
            if param_length != comp_length
                error("Mismatched data size for a parameter connection: dimension :$dim in $(nameof(comp_def))'s parameter $param_name has $comp_length elements; model parameter has $param_length elements")
            end
        end
    end
end

"""
    _check_attributes(obj::AbstractCompositeComponentDef, ipc::InternalParameterConnection)

Check that the dimensions of the source variable match the attributes of the
destination Parameter in InternalParameterConnection `ipc` and an object `obj`. Note
that the names of the dimensions need not match, just the length of dimensions in
the same position.
"""
function _check_attributes(obj::AbstractCompositeComponentDef, ipc::InternalParameterConnection)

        var_def =  Mimi.variable(Mimi.find_comp(obj, ipc.src_comp_path), ipc.src_var_name)
        param_def = Mimi.parameter(Mimi.find_comp(obj, ipc.dst_comp_path), ipc.dst_par_name)

        param_dims = Mimi.dim_names(param_def)
        var_dims = Mimi.dim_names(var_def)

        param_comp_name = nameof(Mimi.find_comp(obj, ipc.dst_comp_path))
        var_comp_name = nameof(Mimi.find_comp(obj, ipc.src_comp_path))

        if size(param_dims) != size(var_dims)
            d1 = size(var_dims)
            d2 = size(param_dims)
            error("Mismatched dimensions of internal parameter connection: ",
                "DESTINATION: Component $(param_comp_name)'s Parameter $(ipc.dst_par_name) (size $d2) ",
                "SOURCE: Component $(var_comp_name)'s Variable $(ipc.src_var_name) (size $d1).")
        end

        for (i, dim) in enumerate(param_dims)
            if isa(dim, Symbol)
                param_dim_size = dim_count(obj,dim)
                var_dim_size = dim_count(obj, var_dims[i])
                
                if param_dim_size != var_dim_size
                    error("Mismatched data size for internal parameter connection: ",
                    "dimension :$dim in $(param_comp_name)'s Parameter $(ipc.dst_par_name) has $param_dim_size elements; ",
                    "while the same positioned (#$i) dimension for $(var_comp_name)'s Variable $(ipc.src_var_name) has $var_dim_size elements.")
                end
            end
        end
end
"""
    _check_attributes(obj::AbstractCompositeComponentDef,
                comp_def::AbstractComponentDef, param_name::Symbol, 
                mod_param::ScalarModelParameter)

Check that the attributes of the ScalarModelParameter `mod_param` match the attributes
of the model parameter `param_name` in component `comp_def` of object `obj`, 
including datatype. 
"""
function _check_attributes(obj::AbstractCompositeComponentDef,
                        comp_def::AbstractComponentDef, param_name::Symbol, 
                        mod_param::ScalarModelParameter)
    
    is_nothing_param(mod_param) && return 

    param_def = parameter(comp_def, param_name)
    t1 = typeof(mod_param.value)
    t2 = param_def.datatype

    if !(t1 <: Union{Missing, t2})
        error("Mismatched datatype of parameter connection: Component: $(nameof(comp_def)) ",
        "Parameter: $param_name ($t2) to Model Parameter with type ($t1). If you are using ",
        "`add_shared_param`! try using the `data_type` keyword argument to specifiy ",
        "data_type = $(param_def.datatype).")
    end

end

"""
    connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol, param_name::Symbol, model_param_name::Symbol;
                   check_attributes::Bool=true, ignoreunits::Bool=false))

Connect a parameter `param_name` in the component `comp_name` of composite `obj` to
the model parameter `model_param_name`.
"""
function connect_param!(obj::AbstractCompositeComponentDef, comp_name::Symbol,
                        param_name::Symbol, model_param_name::Symbol;
                        check_attributes::Bool=true, ignoreunits::Bool = false)
    comp_def = compdef(obj, comp_name)
    connect_param!(obj, comp_def, param_name, model_param_name, check_attributes=check_attributes, ignoreunits = ignoreunits)
end

"""
    connect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                    param_name::Symbol, model_param_name::Symbol; check_attributes::Bool=true,
                    ignoreunits::Bool = false)

Connect a parameter `param_name` in the component `comp_def` of composite `obj` to
the model parameter `model_param_name`.
"""
function connect_param!(obj::AbstractCompositeComponentDef, comp_def::AbstractComponentDef,
                        param_name::Symbol, model_param_name::Symbol; check_attributes::Bool=true,
                        ignoreunits::Bool = false)
    
    mod_param = model_param(obj, model_param_name)

    # check the attributes between the shared model parameter and the component parameter
    check_attributes && _check_attributes(obj, comp_def, param_name, mod_param)

    # check for collisions 
    if is_shared(mod_param)
        conns = filter(i -> i.model_param_name == model_param_name, external_param_conns(obj))
        if !(isempty(conns)) # need to check collisions
            pairs = [compdef(obj, conn.comp_path) => conn.param_name for conn in conns]
            push!(pairs, comp_def => param_name)

            # which fields to check for collisions in subcomponents
            # NB: we don't need the types of the parameters to connected to 
            # exactly match, if they both satisfy _check_attributes above with the 
            # model parameter that is good enough --> we take :datatype out of the
            # fields list below
            fields = ignoreunits ? [:dim_names] : [:dim_names, :unit]

            collisions = _find_collisions(fields, Vector(pairs))
            
            if ! isempty(collisions) 
                if :unit in collisions
                    error("Cannot connect $(nameof(comp_def)):$(param_name) to shared model ",
                            "parameter $model_param_name, it has a conflicting ",
                            ":unit value ($(parameter_unit(comp_def, param_name))) with ",
                            "other parameters connected to this shared model parameter. To ignore ",
                            "this set the `ignoreunits` flag in `connect_param!` to false.")
                else
                    spec = join(collisions, " and ")
                    error("Cannot connect $(nameof(comp_def)):$(param_name) to shared model parameter ",
                        "$model_param_name, it has conflicting values for the $spec of other ",
                        "parameters connected to this shared model parameter.") 
                end
            end
        end
    end

    disconnect_param!(obj, comp_def, param_name)    # calls dirty!()

    comp_path = @or(comp_def.comp_path, ComponentPath(obj.comp_path, comp_def.name))
    conn = ExternalParameterConnection(comp_path, param_name, model_param_name)
    add_external_param_conn!(obj, conn)

    return nothing
end

"""
    _connect_param!(obj::AbstractCompositeComponentDef,
        dst_comp_path::ComponentPath, dst_par_name::Symbol,
        src_comp_path::ComponentPath, src_var_name::Symbol,
        backup::Union{Nothing, Array}=nothing;
        ignoreunits::Bool=false, backup_offset::Int=0)

Bind the parameter `dst_par_name` of one component `dst_comp_path` of composite `obj` to a
variable `src_var_name` in another component `src_comp_path` of the same model using
`backup` to provide default values and the `ignoreunits` flag to indicate the need to
check match units between the two.  The `backup_offset` argument, which is only valid 
when `backup` data has been set, indicates that the backup data should be used for
a specified number of timesteps after the source component begins. ie. the value would be 
`1` if the destination component parameter should only use the source component 
data for the second timestep and beyond.
"""
function _connect_param!(obj::AbstractCompositeComponentDef,
                        dst_comp_path::ComponentPath, dst_par_name::Symbol,
                        src_comp_path::ComponentPath, src_var_name::Symbol,
                        backup::Union{Nothing, Array}=nothing;
                        ignoreunits::Bool=false, backup_offset::Union{Nothing, Int}=nothing)

    dst_comp_def = compdef(obj, dst_comp_path)
    src_comp_def = compdef(obj, src_comp_path)

    # remove any existing connections for this dst parameter
    disconnect_param!(obj, dst_comp_def, dst_par_name)  # calls dirty!()

    # @info "dst_comp_def: $dst_comp_def"
    # @info "src_comp_def: $src_comp_def"

    if backup !== nothing
        # If value is a NamedArray, we can check if the labels match
        if isa(backup, NamedArray)
            dims = dimnames(backup)
            check_parameter_dimensions(obj, backup, dims, dst_par_name)
        else
            dims = nothing
        end

        # Check that the backup data is the right size
        if size(backup) != datum_size(obj, dst_comp_def, dst_par_name)
            error("Cannot connect parameter; the provided backup data is the wrong size. ",
                  "Expected size $(datum_size(obj, dst_comp_def, dst_par_name)) but got $(size(backup)).")
        end

        # convert number type and, if it's a NamedArray, convert to Array
        backup = convert(Array{Union{Missing, number_type(obj)}}, backup)

        dst_param = parameter(dst_comp_def, dst_par_name)
        dst_dims  = dim_names(dst_param)
        dim_count = length(dst_dims)

        ti = get_time_index_position(dst_param)

        if ti === nothing # not time dimension
            values = backup
        else # handle time dimension

            # get first and last of the ModelDef, NOT the ComponentDef
            first = first_period(obj)
            last = last_period(obj) 

            T = eltype(backup)

            if isuniform(obj)
                stepsize = step_size(obj)
                values = TimestepArray{FixedTimestep{first, stepsize, last}, T, dim_count, ti}(backup)
            else
                times = time_labels(obj)
                values = TimestepArray{VariableTimestep{(times...,)}, T, dim_count, ti}(backup)
            end

        end

        # create a backup parameter name with the destination leaf component and 
        # parameter names, as well as a trailing integer to ensure uniqueness in
        # edge cases.  Check if the name is already used, and if so increment the 
        # trailing integer until it is a unique model parameter name to the model
        i = 1
        backup_param_name = Symbol("backup_", dst_comp_path.names[end], "_", dst_par_name, "_", i)
        while haskey(obj.model_params, backup_param_name)
            i += 1
            backup_param_name = Symbol("backup_", dst_comp_path.names[end], "_", dst_par_name, "_", i)
        end

        # NB: potentially unsafe way to add parameter/might be duplicating work so
        # advise shifting to create_model_param ... but leaving it as is for now
        add_model_array_param!(obj, backup_param_name, values, dst_dims)

    else
        # cannot use backup_offset keyword argument if there is no backup
        if backup_offset !== nothing
            error("Cannot set `backup_offset` keyword argument if `backup` data is not explicitly provided")
        end

        # If backup not provided, make sure the source component covers the span of the destination component
        src_first, src_last = first_and_last(src_comp_def)
        dst_first, dst_last = first_and_last(dst_comp_def)
        if (dst_first !== nothing && src_first !== nothing && dst_first < src_first) ||
            (dst_last  !== nothing && src_last  !== nothing && dst_last  > src_last)
            src_first = printable(src_first)
            src_last  = printable(src_last)
            dst_first = printable(dst_first)
            dst_last  = printable(dst_last)
            error("""Cannot connect parameter: $src_comp_path runs only from $src_first to $src_last,
whereas $dst_comp_path runs from $dst_first to $dst_last. Backup data must be provided for missing years.
Try calling:
    `connect_param!(m, comp_name, par_name, comp_name, var_name, backup_data)`""")
        end

        backup_param_name = nothing
    end

    # Check the units, if both are provided
    var_unit = variable_unit(src_comp_def, src_var_name)
    par_unit = parameter_unit(dst_comp_def, dst_par_name)

    if !ignoreunits && var_unit !== "" && par_unit !== "" 
        if ! verify_units(var_unit, par_unit)
            error("Units of $src_comp_path:$src_var_name ($var_unit) do not match $dst_comp_path:$dst_par_name ($par_unit).")
        end
    end

    conn = InternalParameterConnection(src_comp_path, src_var_name, dst_comp_path, dst_par_name,
                                       ignoreunits, backup_param_name, backup_offset=backup_offset)
    add_internal_param_conn!(obj, conn)

    return nothing
end

"""
    connect_param!(obj::AbstractCompositeComponentDef,
                    dst_comp_name::Symbol, dst_par_name::Symbol,
                    src_comp_name::Symbol, src_var_name::Symbol,
                    backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, 
                    backup_offset::Union{Nothing, Int} = nothing)

Bind the parameter `dst_par_name` of one component `dst_comp_name` of composite `obj` to a
variable `src_var_name` in another component `src_comp_name` of the same model using
`backup` to provide default values and the `ignoreunits` flag to indicate the need to
check match units between the two.  The `backup_offset` argument, which is only valid 
when `backup` data has been set, indicates that the backup data should be used for
a specified number of timesteps after the source component begins. ie. the value would be 
`1` if the destination component parameter should only use the source component 
data for the second timestep and beyond.
"""

function connect_param!(obj::AbstractCompositeComponentDef,
                        dst_comp_name::Symbol, dst_par_name::Symbol,
                        src_comp_name::Symbol, src_var_name::Symbol,
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, 
                        backup_offset::Union{Nothing, Int} = nothing)
    _connect_param!(obj, ComponentPath(obj, dst_comp_name), dst_par_name,
                        ComponentPath(obj, src_comp_name), src_var_name,
                        backup; ignoreunits=ignoreunits, backup_offset=backup_offset)
end

"""
    connect_param!(obj::AbstractCompositeComponentDef,
        dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol},
        backup::Union{Nothing, Array}=nothing;
        ignoreunits::Bool=false, backup_offset::Union{Nothing, Int} = nothing)

Bind the parameter `dst[2]` of one component `dst[1]` of composite `obj`
to a variable `src[2]` in another component `src[1]` of the same composite
using `backup` to provide default values and the `ignoreunits` flag to indicate the need
to check match units between the two.  The `backup_offset` argument, which is only valid 
when `backup` data has been set, indicates that the backup data should be used for
a specified number of timesteps after the source component begins. ie. the value would be 
`1` if the destination componentm parameter should only use the source component 
data for the second timestep and beyond.
"""
function connect_param!(obj::AbstractCompositeComponentDef,
                        dst::Pair{Symbol, Symbol}, src::Pair{Symbol, Symbol},
                        backup::Union{Nothing, Array}=nothing; ignoreunits::Bool=false, 
                        backup_offset::Union{Nothing, Int} = nothing)
    connect_param!(obj, dst[1], dst[2], src[1], src[2], backup; ignoreunits=ignoreunits, backup_offset=backup_offset)
end

"""
    split_datum_path(obj::AbstractCompositeComponentDef, s::AbstractString)

Split a string of the form "/path/to/component:datum_name" into the component path,
`ComponentPath(:path, :to, :component)` and name `:datum_name`.
"""
function split_datum_path(obj::AbstractCompositeComponentDef, s::AbstractString)
    elts = split(s, ":")
    length(elts) != 2 && error("Cannot split datum path '$s' into ComponentPath and datum name.")
    return (ComponentPath(obj, elts[1]), Symbol(elts[2]))
end

"""
    connection_refs(obj::AbstractCompositeComponentDef)

Return a vector of UnnamedReference's to parameters from subcomponents that are either found in
internal connections or that have been already imported in a parameter definition.
"""
function connection_refs(obj::AbstractCompositeComponentDef)
    refs = UnnamedReference[]

    for conn in obj.internal_param_conns
        push!(refs, UnnamedReference(conn.dst_comp_path.names[end], conn.dst_par_name))
    end

    for item in values(obj.namespace)
        if item isa CompositeParameterDef
            for ref in item.refs
                push!(refs, ref)
            end
        end
    end

    return refs
end

"""
    connection_refs(obj::ModelDef)

Return a vector of UnnamedReference's to parameters from subcomponents that are either found in
internal connections or that have been already connected to model parameter values.
"""
function connection_refs(obj::ModelDef)
    refs = UnnamedReference[]

    for conn in obj.internal_param_conns
        push!(refs, UnnamedReference(conn.dst_comp_path.names[end], conn.dst_par_name))
    end

    for conn in obj.external_param_conns
        push!(refs, UnnamedReference(conn.comp_path.names[end], conn.param_name))
    end

    return refs
end

"""
    nothing_params(obj::AbstractCompositeComponentDef)

Return a list of UnnamedReference's to parameters that are connected to a model
parameter with a value of nothing.
"""
function nothing_params(obj::AbstractCompositeComponentDef)

    refs = UnnamedReference[]

    for conn in obj.external_param_conns
        param = model_param(obj, conn.model_param_name)
        if is_nothing_param(param)
            push!(refs, UnnamedReference(conn.comp_path.names[end], conn.param_name))
        end
    end
    return refs
end

"""
    is_nothing_param(param::ScalarModelParameter)

Return true if `param`'s value is nothing, and false otherwise.
"""
function is_nothing_param(param::ScalarModelParameter)
    return isnothing(param.value)
end

"""
    is_nothing_param(param::ArrayModelParameter)

Return true if `param`'s values is nothing, and false otherwise.
"""
function is_nothing_param(param::ArrayModelParameter)
    return isnothing(param.values)
end
 
"""
    unconnected_params(obj::AbstractCompositeComponentDef)

Return a list of UnnamedReference's to parameters that have not been connected
to a value.
"""
function unconnected_params(obj::AbstractCompositeComponentDef)
    return setdiff(subcomp_params(obj), connection_refs(obj))
end

"""
    update_leftover_params!(md::ModelDef, parameters::Dict)

Update all of the parameters in `ModelDef` `md` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are Tuples of Symbols (or convertible to Symbols ie. Strings) 
of (comp_name, param_name) that match the component-parameter pair of 
unset parameters in the model.  All resulting connected model parameters will be 
unshared model parameters.
"""
function update_leftover_params!(md::ModelDef, parameters)
    parameters = Dict(Symbol.(k) => v for (k, v) in parameters)
    for param_ref in nothing_params(md)

        param_name = param_ref.datum_name
        comp_name = param_ref.comp_name
        key = (comp_name, param_name)
        if haskey(parameters, key)
            value = parameters[key]
            update_param!(md, comp_name, param_name, value)
        else
            error("Cannot set parameter (:$comp_name, :$param_name), not found in provided dictionary.")
        end
    end
    nothing
end

"""
    set_leftover_params!(md::ModelDef, parameters::Dict)

Set all of the parameters in `ModelDef` `md` that don't have a value and are not connected
to some other component to a value from a dictionary `parameters`. This method assumes
the dictionary keys are Symbols (or convertible into Symbols ie. Strings) that 
match the names of unset parameters in the model. All resulting connected model 
parameters will be shared model parameters.

Note that this function `set_leftover_params! has been deprecated, and uses should
be transitioned to using `update_leftover_params!` with keys specific to component-parameter 
pairs i.e. (comp_name, param_name) => value in the dictionary.
"""
function set_leftover_params!(md::ModelDef, parameters::Dict)
    # @warn "The function `set_leftover_params! has been deprecated, please use `update_leftover_params!` with keys specific to component, parameter pairs i.e. (comp_name, param_name) => value in the dictionary.")
    parameters = Dict(Symbol.(k) => v for (k, v) in parameters)
    for param_ref in nothing_params(md)

        param_name = param_ref.datum_name
        comp_name = param_ref.comp_name

        comp_def = find_comp(md, comp_name)
        param_def = comp_def[param_name]

        # check whether we need to add the model parameter to the ModelDef
        if isnothing(model_param(md, param_name, missing_ok=true))
            if haskey(parameters, param_name)  
                value = parameters[param_name]
                param = create_model_param(md, param_def, value; is_shared = true)
                add_model_param!(md, param_name, param)
            else
                error("Cannot set shared model parameter :$param_name, not found in provided dictionary.")
            end
        end
        connect_param!(md, comp_name, param_name, param_name)
    end
    nothing
end
"""
    internal_param_conns(obj::AbstractCompositeComponentDef, dst_comp_path::ComponentPath)

Return internal param conns to a given destination component on `dst_comp_path` in `obj`.  
"""
function internal_param_conns(obj::AbstractCompositeComponentDef, dst_comp_path::ComponentPath)
    return filter(x->x.dst_comp_path == dst_comp_path, internal_param_conns(obj))
end

"""
    internal_param_conns(obj::AbstractCompositeComponentDef, comp_name::Symbol)

Return internal param conns to a given destination component `comp_name` in `obj`.  
"""
function internal_param_conns(obj::AbstractCompositeComponentDef, comp_name::Symbol)
    return internal_param_conns(obj, ComponentPath(obj.comp_path, comp_name))
end

"""
    add_internal_param_conn!(obj::AbstractCompositeComponentDef, conn::InternalParameterConnection)

Add an internal param conns `conn` to the internal parameter connection lists of `obj`.
"""
function add_internal_param_conn!(obj::AbstractCompositeComponentDef, conn::InternalParameterConnection)
    push!(obj.internal_param_conns, conn)
    dirty!(obj)
end

#
# These should all take ModelDef instead of AbstractCompositeComponentDef as 1st argument
#

"""
    external_param_conns(obj::ModelDef, comp_path::ComponentPath)

Find external param conns for a given comp on path `comp_path` in `obj`.
"""
function external_param_conns(obj::ModelDef, comp_path::ComponentPath)
    return filter(x -> x.comp_path == comp_path, external_param_conns(obj))
end

"""
    external_param_conns(obj::ModelDef, comp_name::Symbol)

Find external param conns for a given comp `comp_name` in `obj`.
"""
function external_param_conns(obj::ModelDef, comp_name::Symbol)
    return external_param_conns(obj, ComponentPath(obj.comp_path, comp_name))
end

"""
    model_param(obj::ModelDef, name::Symbol; missing_ok=false)

Return the ModelParameter in `obj` with name `name`.  If `missing_ok` is set 
to `true`, return nothing if parameter is not found, otherwise error.
"""
function model_param(obj::ModelDef, name::Symbol; missing_ok=false)
    haskey(obj.model_params, name) && return obj.model_params[name]

    missing_ok && return nothing

    error("$name not found in model parameter list.")
end

"""
    model_param(obj::ModelDef, comp_name::Symbol, param_name::Symbol; missing_ok = false)

Return the ModelParameter in `obj` connected to component `comp_name`'s parameter
`param_name`. If `missing_ok` is set to `true`, return nothing if parameter is not 
found, otherwise error.
"""
function model_param(obj::ModelDef, comp_name::Symbol, param_name::Symbol; missing_ok = false)

    model_param_name = get_model_param_name(obj, comp_name, param_name; missing_ok = true)

    if isnothing(model_param_name)
        missing_ok && return nothing
        error("Model parameter connected to $comp_name's parameter $param_name not found in model's parameter connections list.")
    else
        return model_param(obj, model_param_name)
    end

end

"""
    get_model_param_name(obj::ModelDef, comp_name::Symbol, param_name::Symbol; missing_ok=false)

Get the model parameter name for the exernal parameter conneceted to comp_name's
parameter param_name.  The keyword argument `missing_ok` defaults to false so
if no parameter is found an error is thrown, if it is set to true the function will
return `nothing`.
"""
function get_model_param_name(obj::ModelDef, comp_name::Symbol, param_name::Symbol; missing_ok=false)
    for conn in obj.external_param_conns
        if conn.comp_path.names[end] == comp_name && conn.param_name == param_name
            return conn.model_param_name
        end
    end

    missing_ok && return nothing

    error("Model parameter connected to $comp_name's parameter $param_name not found in model's parameter connections list.")
end

"""
    get_model_param_name(obj::Model, comp_name::Symbol, param_name::Symbol; missing_ok=false)

Get the model parameter name for the exernal parameter connected to comp_name's
parameter param_name.  The keyword argument `missing_ok` defaults to false so
if no parameter is found an error is thrown, if it is set to true the function will
return `nothing`.
"""
function get_model_param_name(obj::Model, comp_name::Symbol, param_name::Symbol; missing_ok=false)
    get_model_param_name(obj.md, comp_name, param_name; missing_ok = missing_ok)
end

function add_external_param_conn!(obj::ModelDef, conn::ExternalParameterConnection)
    push!(obj.external_param_conns, conn)
    dirty!(obj)
end

"""
    add_model_param!(md::ModelDef, name::Symbol, value::ModelParameter)

Add an model parameter with name `name` and Model Parameter `value` to ModelDef `md`.
"""
function add_model_param!(md::ModelDef, name::Symbol, value::ModelParameter)
    # if haskey(md.model_params, name)
    #     @warn "Redefining model param :$name in $(md.comp_path) from $(md.model_params[name]) to $value"
    # end
    md.model_params[name] = value
    dirty!(md)
    return value
end


"""
    add_model_param!(md::ModelDef, name::Symbol, value::Number;
                        param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                        is_shared::Bool = false)

Create and add a model parameter with name `name` and Model Parameter `value` 
to ModelDef `md`. The Model Parameter will be created with value `value`, dimensions
`param_dims` which can be left to be created automatically from the Model Def, and 
an is_shared attribute `is_shared` which defaults to false.

WARNING: this has been mostly replaced by combining create_model_param with add_model_param
method using the paramdef ... certain checks are not done here ... should be careful 
using it and only do so under the hood.
"""
function add_model_param!(md::ModelDef, name::Symbol, value::Number;
                            param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                            is_shared::Bool = false)
    # if haskey(md.model_params, name)
    #     @warn "Redefining model param :$name in $(md.comp_path) from $(md.model_params[name]) to $value"
    # end                        
    add_model_scalar_param!(md, name, value, is_shared = is_shared)
end

"""
    add_model_param!(md::ModelDef, name::Symbol, value::Number;
                        param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                        is_shared::Bool = false)

Create and add a model parameter with name `name` and Model Parameter `value` 
to ModelDef `md`. The Model Parameter will be created with value `value`, dimensions
`param_dims` which can be left to be created automatically from the Model Def, and 
an is_shared attribute `is_shared` which defaults to false.
"""
function add_model_param!(md::ModelDef, name::Symbol,
                             value::Union{AbstractArray, AbstractRange, Tuple};
                             param_dims::Union{Nothing,Array{Symbol}} = nothing, 
                             is_shared::Bool = false)
    # if haskey(md.model_params, name)
    #     @warn "Redefining model param :$name in $(md.comp_path) from $(md.model_params[name]) to $value"
    # end  

    ti = get_time_index_position(param_dims)
    if !isnothing(ti)
        value = convert(Array{number_type(md)}, value)
        num_dims = length(param_dims)
        values = get_timestep_array(md, eltype(value), num_dims, ti, value)
    else
        values = value
    end

    add_model_array_param!(md, name, values, param_dims, is_shared = is_shared)
end

"""
    add_model_array_param!(md::ModelDef,
                                name::Symbol, value::TimestepVector, 
                                dims; is_shared::Bool = false)

Add a one dimensional time-indexed array parameter indicated by `name` and
`value` to the Model Def `md`. The `is_shared` attribute of the ArrayModelParameter
will default to false. In this case `dims` must be `[:time]`.
"""
function add_model_array_param!(md::ModelDef,
                                    name::Symbol, value::TimestepVector, 
                                    dims; is_shared::Bool = false)
    param = ArrayModelParameter(value, [:time], is_shared)  # must be :time
    add_model_param!(md, name, param)
end

"""
    add_model_array_param!(md::ModelDef,
                              name::Symbol, value::TimestepMatrix, dims; 
                              is_shared::Bool = false)

Add a multi-dimensional time-indexed array parameter `name` with value
`value` to the Model Def `md`.  The `is_shared` attribute of the ArrayModelParameter
will default to false. In this case `dims` must contain `[:time]`.
"""
function add_model_array_param!(md::ModelDef,
                                name::Symbol, value::TimestepArray, dims; 
                                is_shared::Bool = false)
    !(:time in dims) && error("When adding an `ArrayModelParameter` the dimensions array must include `:time`, but here it is $dims.")
    param = ArrayModelParameter(value, dims, is_shared)
    add_model_param!(md, name, param)
end

"""
    add_model_array_param!(md::ModelDef,
                              name::Symbol, value::AbstractArray, dims; 
                              is_shared::Bool = false)

Add an array type parameter `name` with value `value` and `dims` dimensions to the 
Model Def `md`. The `is_shared` attribute of the ArrayModelParameter will default to 
false. 
"""
function add_model_array_param!(md::ModelDef,
                                   name::Symbol, value::AbstractArray, dims; 
                                   is_shared::Bool = false)
    param = ArrayModelParameter(value, dims === nothing ? Vector{Symbol}() : dims, is_shared)
    add_model_param!(md, name, param)
end

"""
    add_model_scalar_param!(md::ModelDef, name::Symbol, value::Any; is_shared::Bool = false)

Add a scalar type parameter `name` with the value `value` to the Model Def `md`.
"""
function add_model_scalar_param!(md::ModelDef, name::Symbol, value::Any; is_shared::Bool = false)
    param = ScalarModelParameter(value, is_shared)
    add_model_param!(md, name, param)
end

"""
    update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value; update_timesteps = nothing)

Update the `value` of a model parameter in composite `obj`, referenced
by `name`. The update_timesteps keyword argument is deprecated, we keep it here 
just to provide warnings.
"""
function update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value; update_timesteps = nothing)
    !isnothing(update_timesteps) ? @warn("Use of the `update_timesteps` keyword argument is no longer supported or needed, time labels will be adjusted automatically if necessary.") : nothing
    _update_param!(obj::AbstractCompositeComponentDef, name, value)
end

"""
    update_param!(mi::ModelInstance, name::Symbol, value)

Update the `value` of a model parameter in `ModelInstance` `mi`, referenced
by `name`.  This is an UNSAFE update as it does not dirty the model, and should 
be used carefully and specifically for things like our MCS work.
"""
function update_param!(mi::ModelInstance, name::Symbol, value)
    param = mi.md.model_params[name]

    if param isa ScalarModelParameter
        param.value = value
    elseif param.values isa TimestepArray
        copyto!(param.values.data, value)
    else
        copyto!(param.values, value)
    end

    return nothing
end

"""
    update_param!(mi::ModelInstance, comp_name::Symbol, param_name::Symbol, value)

Update the `value` of a model parameter in `ModelInstance` `mi`, connected to 
component `comp_name`'s parameter `param_name`. This is an UNSAFE updat as it does 
not dirty the model, and should  be used carefully and specifically for things like 
our MCS work.
"""
function update_param!(mi::ModelInstance, comp_name::Symbol, param_name::Symbol, value)

    model_param_name = get_model_param_name(mi.md, comp_name, param_name)
    param = model_param(mi.md, model_param_name)

    is_shared(param) && error("$comp_name:$param_name is connected to a ",
            "a shared model parameter with name $model_param_name in the model, ",
            "to update the shared model parameter please call `update_param!(mi, $model_param_name, value)` ", 
            "to explicitly update a shared parameter that may be connected to ", 
            "several components. If you want to disconnect $comp_name:$param_name ",
            "from the shared model parameter and connect it to it's own unshared ",
            "model parameter, first use `disconnect_param!` and then you can use this same ", 
            "call to `update_param!`.")

    if param isa ScalarModelParameter
        param.value = value
    elseif param.values isa TimestepArray
        copyto!(param.values.data, value)
    else
        copyto!(param.values, value)
    end

    return nothing
end

"""
    update_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, value)

Update the `value` of the unshared model parameter in Model Def `md` connected to component 
`comp_name`'s parameter `param_name`. 
"""
function update_param!(md::ModelDef, comp_name::Symbol, param_name::Symbol, value)

    model_param_name = get_model_param_name(md, comp_name, param_name; missing_ok = true)

    # check if we need a new parameter, maybe because it was previously a nothing
    # parameter that got disconnected
    if isnothing(model_param_name)
        
        comp_def = find_comp(md, comp_name)
        param_def = comp_def[param_name]

        param = create_model_param(md, param_def, value; is_shared = false)

        model_param_name = gensym()
        add_model_param!(md, model_param_name, param)

        connect_param!(md, comp_name, param_name, model_param_name)
        dirty!(md)

    # update existing parameter
    else
        mod_param = model_param(md, model_param_name)
        is_shared(mod_param) && error("$comp_name:$param_name is connected to a ",
                "a shared model parameter with name $model_param_name in the model, ",
                "to update the shared model parameter please call `update_param!(m, $model_param_name, value)` ", 
                "to explicitly update a shared parameter that may be connected to ", 
                "several components. If you want to disconnect $comp_name:$param_name ",
                "from the shared model parameter and connect it to it's own unshared ",
                "model parameter, first use `disconnect_param!` and then you can use this same ", 
                "call to `update_param!`.")

        # update the parameter
        _update_param!(md, model_param_name, value)
    end
end

"""
    _update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value)

Update the `value` of the model parameter `name` in Model Def `md`.
"""
function _update_param!(obj::AbstractCompositeComponentDef, name::Symbol, value)
    param = model_param(obj, name, missing_ok=true)
    if param === nothing
        error("Cannot update parameter $name; $name not found in composite's model parameters.")
    end

    # handle nothing params
    if is_nothing_param(param)
        _update_nothing_param!(obj, name, value)
    else
        if param isa ScalarModelParameter
            _update_scalar_param!(param, name, value)
        else
            _update_array_param!(obj, name, value)
        end
    end
    dirty!(obj)
end

"""
    _update_scalar_param!(param::ScalarModelParameter, name, value)

Update the `value` of the scalar model parameter `param`.
"""
function _update_scalar_param!(param::ScalarModelParameter, name, value)
    if ! (value isa typeof(param.value))
        try
            value = convert(typeof(param.value), value)
        catch e
            error("Cannot update parameter $name; expected type $(typeof(param.value)) but got $(typeof(value)).")
        end
    end
    param.value = value
    nothing
end

"""
    _update_array_param!(obj::AbstractCompositeComponentDef, name, value)

Update the `value` of the array model parameter `name` in object `obj`.
"""
function _update_array_param!(obj::AbstractCompositeComponentDef, name, value)
   
    # Get original parameter
    param = model_param(obj, name)

    # Check type of provided parameter
    if !(typeof(value) <: AbstractArray)
        error("Cannot update array parameter $name with a value of type $(typeof(value)).")

    elseif !(eltype(value) <: eltype(param.values))
        try
            value = convert(Array{eltype(param.values)}, value)
        catch e
            error("Cannot update parameter $name; expected array of type $(eltype(param.values)) but got $(eltype(value)).")
        end
    end

    # Check if the parameter dimensions match the model dimensions.  Note that we 
    # previously checked if parameter dimensions matched the dimensions of the 
    # parameter they were to replace, but given dimensions of a model can be changed,
    # we now choose to enforce that the new dimensions match the current model state, 
    # whatever that is.

    expected_size = ([length(dim_keys(obj, d)) for d in dim_names(param)]...,) 
    size(value) != expected_size ? error("Cannot update parameter $name; expected array of size $expected_size but got array of size $(size(value)).") : nothing

    # check if updating timestep labels is necessary
    if param.values isa TimestepArray
        time_label_change = time_labels(param.values) != dim_keys(obj, :time)
        N = ndims(value)
        if time_label_change
            T = eltype(value)
            ti = get_time_index_position(param)
            new_timestep_array = get_timestep_array(obj, T, N, ti, value)
            # NB: potentially unsafe way to add parameter/might be duplicating work so
            # advise shifting to create_model_param ... but leaving it as is for now
            # since this is a special case of replacing an existing model param
            add_model_param!(obj, name, ArrayModelParameter(new_timestep_array, dim_names(param), param.is_shared))
        else
            copyto!(param.values.data, value)
        end
    else
        copyto!(param.values, value)
    end

    dirty!(obj)
    nothing
end

"""
    _update_nothing_param!(obj::AbstractCompositeComponentDef, name::Symbol, value)

Update the `value` of the model parameter `name` in object `obj` where the model
parameter has an initial value of nothing likely from instanitate during `add_comp!`.
"""
function _update_nothing_param!(obj::AbstractCompositeComponentDef, name::Symbol, value)

    # get the component def and param def
    conn = filter(i -> i.model_param_name == name, obj.external_param_conns)[1]
    param_name = conn.param_name

    comp_def = find_comp(obj, conn.comp_path)
    param_def = comp_def[param_name]

    # create the unshared model parameter
    param = create_model_param(obj, param_def, value)
    
    # Need to check the dimensions of the parameter data against component 
    # before adding it to the model's parameter list
    _check_attributes(obj, comp_def, param_name, param)
    
    # add the unshared model parameter to the model def, which will replace the
    # old one and thus keep the connection in tact
    add_model_param!(obj, name, param)
end

"""
    update_params!(obj::AbstractCompositeComponentDef, parameters::Dict; update_timesteps = nothing)

For each (k, v) in the provided `parameters` dictionary, `update_param!`
is called to update the model parameter identified by k to value v.

For updating unshared parameters, each key k must be a Tuple matching the name of a 
component in `obj` and the name of an parameter in that component.

For updating shared parameters, each key k must be a symbol or convert to a symbol 
matching the name of a shared model parameter that already exists in the model.
"""
function update_params!(obj::AbstractCompositeComponentDef, parameters::Dict; update_timesteps = nothing)
    !isnothing(update_timesteps) ? @warn("Use of the `update_timesteps` keyword argument is no longer supported or needed, time labels will be adjusted automatically if necessary.") : nothing
    parameters = Dict(Symbol.(k) => v for (k, v) in parameters)
    for (k, v) in parameters
        if k isa Tuple
            model_param_name = get_model_param_name(obj, first(k), last(k))
        else
            model_param_name = k
        end 
        _update_param!(obj, model_param_name, v)
    end
    nothing
end

"""
    add_connector_comps!(obj::AbstractCompositeComponentDef)

Add all the needed Mimi connector components to object `obj`.
"""
function add_connector_comps!(obj::AbstractCompositeComponentDef)
    conns = internal_param_conns(obj)
    i = 1 # counter to track the number of connector comps added

    for comp_def in compdefs(obj)
        comp_name = nameof(comp_def)
        comp_path = comp_def.comp_path

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_path == comp_path, conns)
        need_conn_comps = filter(x -> x.backup !== nothing, internal_conns)

        # isempty(need_conn_comps) || @info "Need connectors comps: $need_conn_comps"

        for conn in need_conn_comps
            add_backup!(obj, conn.backup)

            num_dims = length(size(model_param(obj, conn.backup).values))

            if ! (num_dims in (1, 2))
                error("Connector components for parameters with > 2 dimensions are not implemented.")
            end

            # Fetch the definition of the appropriate connector commponent
            conn_comp_def = (num_dims == 1 ? Mimi.ConnectorCompVector : Mimi.ConnectorCompMatrix)
            conn_comp_name = connector_comp_name(i) # generate a new name
            i += 1 # increment connector comp counter

            # Add the connector component before the user-defined component that 
            # required it, and for now let the first and last of the component 
            # be free and thus be set to the same as the model
            conn_comp = add_comp!(obj, conn_comp_def, conn_comp_name, before=comp_name)
            if num_dims == 2
                set_dimension!(obj, :ConnectorCompMatrix_Dim2, 1:size(model_param(obj, conn.backup).values,2))
            end
            conn_path = conn_comp.comp_path

            # remove the connections added in add_comp!
            disconnect_param!(obj, conn_comp, :input1)
            disconnect_param!(obj, conn_comp, :input2)

            # add a connection between src_component and the ConnectorComp
            add_internal_param_conn!(obj, InternalParameterConnection(conn.src_comp_path, conn.src_var_name,
                                                                      conn_path, :input1,
                                                                      conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            add_internal_param_conn!(obj, InternalParameterConnection(conn_path, :output,
                                                                      conn.dst_comp_path, conn.dst_par_name,
                                                                      conn.ignoreunits))

            # add a connection between ConnectorComp and the external backup data
            add_external_param_conn!(obj, ExternalParameterConnection(conn_path, :input2, conn.backup))

            # set the first and last parameters for WITHIN the component which 
            # decide when backup is used and when connection is used
            src_comp_def = compdef(obj, conn.src_comp_path)

            param_last = last_period(obj, src_comp_def)
            param_first = first_period(obj, src_comp_def)
            conn.backup_offset !== nothing ? param_first = param_first + conn.backup_offset : nothing

            set_param!(obj, conn_comp_name, :first, Symbol(conn_comp_name, "_", :first), param_first)
            set_param!(obj, conn_comp_name, :last, Symbol(conn_comp_name, "_", :last), param_last)
        end
    end

    return nothing
end


"""
    _pad_parameters!(obj::ModelDef)

Take each model parameter of the Model Definition `obj` and `update_param!` 
with new data values that are altered to match a new time dimension by (1) trimming
the values down if the time dimension has been shortened and (2) padding with missings 
as necessary.
"""
function _pad_parameters!(obj::ModelDef)

    model_times = time_labels(obj)

    for (name, param) in obj.model_params
        # there is only a chance we need to pad a parameter if:
        #   (1) it is an ArrayModelParameter
        #   (2) it has a time dimension
        #   (3) it does not have a values attribute of nothing, as assigned on initialization
        if (param isa ArrayModelParameter) && (:time in param.dim_names) && !is_nothing_param(param)

           param_times = _get_param_times(param)
           padded_data = _get_padded_data(param, param_times, model_times)
           update_param!(obj, name, padded_data)

        end
    end
end

"""
    _get_padded_data(param::ArrayModelParameter, param_times::Vector, model_times::Vector)

Obtain the new data values for the Array Model Paramter `param` with current 
time labels `param_times` such that they are altered to match a new time dimension 
with keys `model_times` by (1) trimming the values down if the time dimension has 
been shortened and (2) padding with missings as necessary.
"""
function _get_padded_data(param::ArrayModelParameter, param_times::Vector, model_times::Vector)

    data = param.values.data
    ti = get_time_index_position(param)

    # first handle the back end 
    model_last = last(model_times)
    param_last = last(param_times)

    if model_last < param_last # trim down the data
        
        trim_idx = findfirst(isequal(last(model_times)), param_times) 
        idxs = repeat(Any[:], ndims(data))
        idxs[ti] = 1:trim_idx
        data = data[idxs...]

    elseif model_last > param_last # pad the data

        pad_length = length(model_times[findfirst(isequal(param_last), model_times)+1:end])
        dims = [size(data)...]
        dims[ti] = pad_length
        end_padding_rows = Array{Union{Missing, Number}}(missing, dims...)
        data = vcat(data, end_padding_rows)

    end

    # now handle the front end 
    model_first = first(model_times)
    param_first = first(param_times)

    # note we do not allow for any trimming off the front end
    if model_first < param_first

        pad_length = length(model_times[1:findfirst(isequal(param_first), model_times)-1])
        dims = [size(data)...]
        dims[ti] = pad_length
        begin_padding_rows = Array{Union{Missing, Number}}(missing, dims...)
        data = vcat(begin_padding_rows, data)

    end

    return data 
end

"""
    _get_param_times(param::ArrayModelParameter{TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti, S}})

Return the time labels that parameterize the `TimestepValue` which in turn parameterizes
the ArrayModelParameter `param`. 
"""
function _get_param_times(param::ArrayModelParameter{TimestepArray{FixedTimestep{FIRST, STEP, LAST}, T, N, ti, S}}) where {FIRST, STEP, LAST, T, N, ti, S}
    return collect(FIRST:STEP:LAST)
end

"""
    _get_param_times(param::ArrayModelParameter{TimestepArray{VariableTimestep{TIMES}, T, N, ti, S}})

Return the time labels that parameterize the `TimestepValue` which in turn parameterizes
the ArrayModelParameter `param`. 
"""
function _get_param_times(param::ArrayModelParameter{TimestepArray{VariableTimestep{TIMES}, T, N, ti, S}}) where {TIMES, T, N, ti, S}
    return [TIMES...]
end

"""
    add_shared_param!(md::ModelDef, name::Symbol, value::Any; dims::Array{Symbol}=Symbol[])

User-facing API function to add a shared parameter to Model Def `md` with name
`name` and value `value`, and an array of dimension names `dims` which dfaults to 
an empty vector.  The `is_shared` attribute of the added Model Parameter will be `true`.

The `value` can by a scalar, an array, or a NamedAray. Optional keyword argument 'dims' is a list
of the dimension names of the provided data, and will be used to check that they match the
model's index labels. Optional keyword argument `datatype` allows user to specify a datatype
to use for the shared model parameter.
"""
function add_shared_param!(md::ModelDef, name::Symbol, value::Any; dims::Array{Symbol}=Symbol[], data_type::DataType=Nothing)
    
    # Check provided name: make sure shared model parameter name does not exist already
    has_parameter(md, name) && error("Cannot add parameter :$name, the model already has a shared parameter with this name.")

    # Check provided dims: 
    #   (1) handle NamedArray
    #   (2) make sure provided dims names exist in the model
    #   (3) make sure number of provided dims matches value

    if value isa NamedArray 
        !isempty(dims) && dims !== dimnames(value) && @warn "Provided dims are $dims, provided NamedArray value has dims $(dimnames(value)), will use value dims $(dimnames(value))."
        dims = dimnames(value)
    end
    
    for dim in dims
        isa(dim, Symbol) && !has_dim(md, dim) && error("Model doesn't have dimension :$dim indicated in the dims of added shared parameter, $dims.")
    end

    if value isa AbstractArray && ndims(value) != length(dims)
        error("Please provide $(ndims(value)) dimension names for value, $(length(dims))",
        " were given but provided value has $(ndims(value)). This is done with the `dims` keyword argument ",
        " ie. : `add_shared_param!(md, name, value; dims = [:time])")
    end
    
    # get the data type to use to create ParameterDef, which we either get from 
    # the data_type argument and just check against provided data in `value`, or we 
    # infer from the provided data in `value` with the caveat that any number
    # type will be raised to number_type(md) for now (except Bools)
    value, data_type = _resolve_datatype(md, value, data_type)
            
    # create the ParameterDef

    # note here that this will take our `data_type` and provide some logic including
    # if data_type == Number it will create a ParameterDef with datatype md.number_type
    # which is also what we do above
    param_def = ParameterDef(name, nothing, data_type, dims, "", "", nothing)

    # create the model parameter
    param = create_model_param(md, param_def, value; is_shared = true)

    # double check the dimensions between the model and the created parameter
    param_dims = dim_names(param_def)
    for (i, dim) in enumerate(param_dims)
        if isa(dim, Symbol)
            param_length = size(param.values)[i]
            model_length = dim_count(md, dim)
            if param_length != model_length
                error("Mismatched data size for new shared param: dimension :$dim in model has $model_length elements; parameter :$name value $param_length elements.")
            end
        end
    end

    # add the shared model parameter to the model def
    add_model_param!(md, name, param)
    
end

# helper functions to return the data_type and (maybe converted) value to use
# in creation of ParameterDef that will parameterize our new added shared model
# parameter

function _resolve_datatype(md::ModelDef, value::Any, data_type::DataType)
    
    # if a data_type is not provided get it from `value`
    if data_type <: Nothing
        value, data_type = _resolve_datatype_nothing(md, value, data_type)
    
    # otherwise check data_type against DataType of `value ``
    else
        value, data_type = _resolve_datatype_value(md, value, data_type)
    end

    return value, data_type
end

function _resolve_datatype_nothing(md::ModelDef, value::Any, data_type::DataType)

    value_data_type = value isa AbstractArray ? eltype(value) : typeof(value)

    # if it is not a DataType, try manually converting first ...
    if !(value_data_type isa DataType)
        try  value = convert(DataType, value_data_type)
        catch; end
    end

    # if it is still not a DataType, try converting it to a Number and if 
    # successful convert the values and update the data_type
    if !(value_data_type isa DataType)
        try value = convert.(Number, value)
        catch; end
        value_data_type = eltype(value) 
    end

    # if it still isn't a datatype, then I give up just go with Any
    if !(value_data_type isa DataType)
        value_data_type = Any 
    end

    # raise to Number to lower the constraints, except for a Boolean make a
    # corner case exception
    if value_data_type <: Number && !(value_data_type <: Bool)
        value_data_type = number_type(md)
    end

    return value, value_data_type
end

function _resolve_datatype_value(md::ModelDef, value::Any, data_type::DataType)

    value_data_type = value isa AbstractArray ? eltype(value) : typeof(value)
    if value_data_type != data_type

        # mirrors what we do in _update_param!
        if value isa AbstractArray
            try  
                value = convert(Array{data_type}, value) 
            catch e
                error("Mismatched datatypes: elements of provided `value` have a ",
                "DataType ($value_data_type) and cannot be converted to the provided ",
                "DataType in `data_type` argument ($data_type). Please resolve by ", 
                "converting the data you provided or changing the `data_type` argument.")
            end
        else
            try 
                value = convert(data_type, value)
            catch e
                error("Mismatched datatypes: `value` has a ",
                "DataType ($value_data_type) and do not match the provided ",
                "DataType in `data_type` argument ($data_type). Please resolve by ", 
                "converting the data you provided or changing the `data_type` argument.")
            end
        end
    end

    return value, data_type
end

"""
    create_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)

Create a new model parameter to be added to Model Def `md` with specifications
matching parameter definition `param_def` and with `value`.  The keyword argument
is_shared defaults to false, and thus an unshared parameter would be created, whereas
setting `is_shared` to true creates a shared parameter.
"""
function create_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)
    if dim_count(param_def) > 0
        return create_array_model_param(md, param_def, value; is_shared = is_shared)
    else
        return create_scalar_model_param(md, param_def, value; is_shared = is_shared)
    end
end

"""
    create_array_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)

Create a new array model parameter to be added to Model Def `md` with specifications
matching parameter definition `param_def` and with `value`.  The keyword argument
is_shared defaults to false, and thus an unshared parameter would be created, whereas
setting `is_shared` to true creates a shared parameter.
"""
function create_array_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)

    # gather info
    param_name = nameof(param_def)
    param_dims = dim_names(param_def)
    num_dims = dim_count(param_def)
    data_type = param_def.datatype

    # data type
    dtype = Union{Missing, (data_type == Number ? number_type(md) : data_type)}

    # create a sentinal unshared parameter
    if isnothing(value)
        param = ArrayModelParameter(value, param_dims, is_shared)
    
    # have a value - in the initiliazation of parameters case this is a default
    # value set in defcomp
    else
              
        # check dimensions
        if value isa NamedArray
            dims = dimnames(value)
            dims !== nothing && check_parameter_dimensions(md, value, dims, param_name)
        end
                
        # convert the number type and, if NamedArray, convert to Array
        if dtype <: AbstractArray
            value = convert(dtype, value)
        else
            # check that number of dimensions matches
            value_dims = length(size(value))
            if num_dims != value_dims
                error("Mismatched data size: dimension :$param_name",
                    " in has $num_dims dimensions; indicated value",
                    " has $value_dims dimensions.")
            end
            value = convert(Array{dtype, num_dims}, value)
        end

        # create TimestepArray if there is a time dim
        ti = get_time_index_position(param_dims)
        if ti !== nothing   # there is a time dimension
            T = eltype(value)
            values = get_timestep_array(md, T, num_dims, ti, value)            
        else
            values = value
        end
             
        param = ArrayModelParameter(values, param_dims, is_shared)
    end
    return param
end

"""
    create_scalar_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)

Create a new scalar model parameter to be added to Model Def `md` with specifications
matching parameter definition `param_def` and with `value`.  The keyword argument
is_shared defaults to false, and thus an unshared parameter would be created, whereas
setting `is_shared` to true creates a shared parameter.
"""
function create_scalar_model_param(md::ModelDef, param_def::AbstractParameterDef, value::Any; is_shared::Bool = false)

    # gather info
    param_name = nameof(param_def)
    param_dims = dim_names(param_def)
    num_dims = dim_count(param_def)
    data_type = param_def.datatype

    # get data type
    dtype = Union{Missing, (data_type == Number ? number_type(md) : data_type)}

    # create a sentinal unshared parameter
    if isnothing(value)
        param = ScalarModelParameter(value, is_shared)

    # have a value - in the initiliazation of parameters case this is a default
    # value set in defcomp
    else
        value = convert(dtype, value)
        param = ScalarModelParameter(value, is_shared)
    end
    
    return param
end

##
## DEPRECATIONS - Should move from warning --> error --> removal
##

# -- throw errors -- 

# -- throw warnings -- 

@deprecate external_param(obj::ModelDef, name::Symbol; missing_ok=false) model_param(obj, name,; missing_ok = missing_ok)

@deprecate set_external_param!(obj::ModelDef, name::Symbol, value::ModelParameter) add_model_param!(obj, name, value)
@deprecate set_external_param!(obj::ModelDef, name::Symbol, value::Number; param_dims::Union{Nothing,Array{Symbol}} = nothing, is_shared::Bool = false) add_model_param!(obj, name, value; param_dims = param_dims, is_shared = is_shared)
@deprecate set_external_param!(obj::ModelDef, name::Symbol, value::Union{AbstractArray, AbstractRange, Tuple}; param_dims::Union{Nothing,Array{Symbol}} = nothing, is_shared::Bool = false) add_model_param!(obj, name, value; param_dims = param_dims, is_shared = is_shared)

@deprecate set_external_array_param!(obj::ModelDef, name::Symbol, value::TimestepVector, dims; is_shared::Bool = false) add_model_array_param!(obj, name, value, dims; is_shared = is_shared)
@deprecate set_external_array_param!(obj::ModelDef, name::Symbol, value::TimestepArray, dims;  is_shared::Bool = false) add_model_array_param(obj, name, value, dims; is_shared = is_shared)
@deprecate set_external_array_param!(obj::ModelDef, name::Symbol, value::AbstractArray, dims; is_shared::Bool = false) add_model_array_param(obj, name, value, dims; is_shared = is_shared)

@deprecate set_external_scalar_param!(obj::ModelDef, name::Symbol, value::Any; is_shared::Bool = false) add_model_scalar_param(obj, name, value; is_shared = is_shared)
