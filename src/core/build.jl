# Create the run_timestep function for this component
function define_run_func(compdef::ComponentDef)
    @eval($(run_expr(compdef)))
end

# Create a ComponentId subtype for the given symbol and return
# the singleton instance, which is the "id" of this component.
function newcomponent(name::Symbol)
    eval(:( esc(struct $name <: ComponentId end)))
    comp_id = get_comp_id(name)
    addcomponent(comp_id)
    return comp_id
end

newcomponent(s::String) = newcomponent(Symbol(s))


function add_connector_comps(m::Model, 
                             mi_comps::ComponentInstanceDict, 
                             mi_conns::Vector{InternalParameterConnection}, 
                             backups::Vector{Symbol})
    connector_count = 0
    
    for c in components(m)
        # first need to see if we need to add any connector components for this component
        int_connections = filter(x->x.target_comp_name == c, internal_parameter_connections(m))
        need_connector_comps = filter(x->(x.backup != nothing), int_connections)

        for conn in need_connector_comps
            connector_count += 1
            push!(backups, conn.backup)
            conn_comp_id = newcomponent("ConnectorComp$connector_count")
            num_dims = length(size(external_parameter(m, conn.backup)))

            #
            # TBD: need to instantiate a ComponentInstance
            #
            if num_dims == 1
                curr = ComponentInstance(conn_comp_id, :ConnectorCompVector, c.offset, c.final)
            elseif num_dims == 2
                curr = ComponentInstance(conn_comp_id, :ConnectorCompMatrix, c.offset, c.final)
            else
                error("Connector components for parameters with more than two dimensions not implemented.")
            end
            mi_comps[comp_id] = curr # add the ConnectorComp to the ordered list of components

            # add a connection between source_component and the ConnectorComp
            push!(mi_conns, InternalParameterConnection(conn.source_variable_name, conn.source_comp_id, 
                                                        :input1, conn_comp_id, conn.ignoreunits))

            # add a connection between ConnectorComp and target_component
            push!(mi_conns, InternalParameterConnection(:output, conn_comp_id, conn.target_parameter_name, 
                                                        conn.target_comp_id, conn.ignoreunits))
        end

        # Now add the other InternalParameterConnections to the list of connections.
        for conns in setdiff(int_connections, need_connector_comps)
            push!(mi_conns, conns)
        end

        # Order is imperative: this component is added after any ConnectorComps were added.
        mi_comps[c] = c 
    end

    return connector_count
end


function instantiate_variables(m::Model, mi_components::ComponentInstanceDict, duration)
    mi_vars = Dict{Tuple{Symbol,Symbol}, Any}()

    for (comp_id, ci) in mi_components
        vars = variables(ci)
        for (vname, v) in vars
            concreteVariableType = v.datatype == Number ? number_type(m) : v.datatype
            vdims = length(v.dimensions)

            if vdims == 0
                mi_vars[(comp_id, v.name)] = Ref{concreteVariableType}()

            elseif vdims == 1 && v.dimensions[1] == :time
                mi_vars[(comp_id, v.name)] = TimestepVector{concreteVariableType, ci.offset, duration}(indexcount(m, :time))

            elseif vdims == 2 && v.dimensions[1] == :time
                mi_vars[(comp_id, v.name)] = TimestepMatrix{concreteVariableType, ci.offset, duration}(indexcount(m, :time), 
                                                                                                        indexcount(m, v.dimensions[2]))
            else
                # TODO Handle unnamed indices properly
                dim_counts = [indexcount(m, i) for i in v.dimensions]
                mi_vars[(comp_id, v.name)] = Array{concreteVariableType, length(v.dimensions)}(dim_counts...)
            end
        end
    end

    return mi_vars
end

# Instantiate a single component
function instantiate_component(m::Model, comp_id::ComponentId,
                               mi_comps::ComponentInstanceDict,
                               mi_conns::Vector{InternalParameterConnection}, duration)
    ext_connections = filter(x->x.comp_id == comp_id, external_parameter_connections(m))
    ext_params = map(x->x.param_name, ext_connections)

    int_connections = filter(x->x.target_comp_id == comp_id, mi_conns)
    int_params = Dict(x.target_parameter_name => x for x in int_connections)

    # TBD: modify this to create a ComponentInstance, something like this:
    vars = ComponentInstanceVariables{VNAMES, VTYPES}()
    pars = ComponentInstanceParameters{PNAMES, PTYPES}()   
    comp = ComponentInstance{vars, pars}()

    # Old way:
    # constructor = Expr(:call, c.component_type, number_type(m), 
    #                    :(Val{$(c.offset)}), :(Val{$duration}), :(Val{$(c.final)}))

    conn_comp_matrix = get_comp_id(:ConnectorCompMatrix)
    conn_comp_vector = get_comp_id(:ConnectorCompVector)
    
    # for each parameter of component c, add the offset and duration as a parametric type to the 
    # constructor call for the component.
    for (pname, p) in parameters(comp_id)
        if 0 < length(p.dimensions) <= 2 && p.dimensions[1] == :time
            #
            # TBD: The special case of :input2 needs documentation
            #
            if pname == :input2 && (comp_name in (:ConnectorCompMatrix, :ConnectorCompVector))
                offset = comp.offset

            elseif pname in ext_params
                offset = getoffset(external_parameter_values(pname))

            elseif (pname, p) in int_params
                offset = mi_comps[p.source_comp_id].offset

            else
                error("unset parameter $pname; should be caught earlier")
            end

            append!(constructor.args, [:(Val{$offset}), :(Val{$duration})])
        end
    end

    push!(constructor.args, indexcount(m))
    println("\nConstructor: $constructor")

    comp = eval(eval(constructor))
    println("Comp: $comp")

    # TBD: this fails because components are not ComponentInstances, but are the 
    # old form, e.g., ::_mimi_implementation_Foo.FooImpl{Float64,1,1,1}, ::Symbol)
    builtComponents[c.name] = comp

    push!(offsets, c.offset)
    push!(final_times, c.final)
end

function instantiate_components(m::Model, mi_components::ComponentInstanceDict,
                                mi_connections::Vector{InternalParameterConnection}, duration)
    built_comps = ComponentInstanceDict()

    # loop over Component, including new ConnectorComps, in order.
    for (comp_name, comp_def) in components(m)
        comp_inst = instantiate_component(m, comp_def, mi_components, mi_connections, duration)
        built_comps[comp_name] = comp_inst
    end

    return built_comps
end

function build(m::Model)
    # check if all parameters are set
    unset = get_unconnected_parameters(m)
    if ! isempty(unset)
        msg = "Cannot build model; the following parameters are unset: "
        for p in unset
            msg = string(msg, p, " ")
        end
        error(msg)
    end

    # Internal connections that the ModelInstance will know about.
    mi_connections = Vector{InternalParameterConnection}() 
    
    # Ordered list of components (including hidden ConnectorComps) that the ModelInstance will use.
    mi_comps = ComponentInstanceDict() 
    
    # Names of external parameters that the ConnectorComps will use as their :input2 parameters.
    backups = Vector{Symbol}() 
    num_connector_comps = 0

    duration = getduration(m)     # for now, all components have the same duration

    # Loop through the components to add necessary ConnectorComps and instantiate variables
    num_connector_comps = add_connector_comps(m, mi_comps, mi_connections, backups)
    mi_var = instantiate_variables(m, mi_comps, duration)

    #######################################################################
    # TBD This is where DA gave up :) Stuff above this line might work,
    # below certainly not.
    #######################################################################
    
    built_comps = instantiate_components(m, mi_comps, mi_connections, duration)

    offsets = Vector{Int}()
    final_times = Vector{Int}()

    for comp in built_comps
        push!(offsets,     comp.offset)
        push!(final_times, comp.final)
    end

    # Make the internal parameter connections, including new hidden connections between ConnectorComps.
    for ipc in mi_connections
        target_comp = built_comps[ipc.target_comp_name]
        source_comp = built_comps[ipc.source_comp_name]
        param_name = ipc.target_parameter_name
        var_name = ipc.source_variable_name
        value = get_parameter_value(source_comp, var_name)
        set_parameter_value(target_comp, param_name, value)
    end

    # Make the external parameter connections.
    for x in external_parameter_connections(m)
        param = external_parameter(m, x.external_parameter)
        comp = built_comps[x.comp_name]
        set_parameter_value(comp, x.param_name, getvalue(param))
    end

    # Make the external parameter connections for the hidden ConnectorComps: connect each :input2 to its associated backup value.
    for i in 1:num_connector_comps
        comp_name = Symbol("ConnectorComp$i")
        param = external_parameter(m, backups[i])
        set_parameter_value(built_comps[comp_name], :input2, getvalue(param))
    end

    m.mi = mi = ModelInstance(m.model_def, built_comps, mi_connections, offsets, final_times)
    return mi
end
