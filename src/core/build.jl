# Create the run_timestep function for this component
function define_run_func(compdef::ComponentDef)
    @eval($(get_run_expr(compdef)))
end


function add_connector_comps(m::Model, 
                             mi_components::OrderedDict{Symbol, ComponentInstanceInfo}, 
                             mi_connections::Vector{InternalParameterConnection}, 
                             backups::Vector{Symbol})
    num_connector_comps = 0
    
    for c in values(m.components2)
        # first need to see if we need to add any connector components for this component
        int_connections = filter(x->x.target_component_name==c.name, m.internal_parameter_connections)
        need_connector_comps = filter(x->(x.backup != nothing), int_connections)

        for ipc in need_connector_comps
            num_connector_comps += 1
            push!(backups, ipc.backup)
            curr_name = Symbol("ConnectorComp$num_connector_comps")
            num_dims = length(size(m.external_parameters[ipc.backup].values))
            if num_dims == 1
                curr = ComponentInstanceInfo(curr_name, ConnectorCompVector, c.offset, c.final)
            elseif num_dims ==2
                curr = ComponentInstanceInfo(curr_name, ConnectorCompMatrix, c.offset, c.final)
            else
                error("Connector components for parameters with more than two dimensions not implemented.")
            end
            mi_components[curr_name] = curr # add the ConnectorComp to the ordered list of components

            # add a connection between source_component and the ConnectorComp
            push!(mi_connections, InternalParameterConnection(ipc.source_variable_name, ipc.source_component_name, 
                                                              :input1, curr_name, ipc.ignoreunits))

            # add a connection between ConnectorComp and target_component
            push!(mi_connections, InternalParameterConnection(:output, curr_name, ipc.target_parameter_name, 
                                                              ipc.target_component_name, ipc.ignoreunits))
        end

        # Now add the other InternalParameterConnections to the list of connections.
        for ipc in setdiff(int_connections, need_connector_comps)
            push!(mi_connections, ipc)
        end

        # Order is imperative: this component is added after any ConnectorComps were added.
        mi_components[c.name] = c 
    end

    return num_connector_comps
end


function instantiate_variables(m::Model, mi_components::OrderedDict{Symbol, ComponentInstanceInfo}, duration)
    mi_vars = Dict{Tuple{Symbol,Symbol}, Any}()

    for (c_name, comp_info) in mi_components
        vars = getvariables(comp_info.component_type.name)
        for (vname, v) in vars
            concreteVariableType = v.datatype == Number ? m.numberType : v.datatype
            if length(v.dimensions) == 0
                mi_vars[(c_name,v.name)] = Ref{concreteVariableType}()
            elseif length(v.dimensions) == 1 && v.dimensions[1] == :time
                mi_vars[(c_name,v.name)] = TimestepVector{concreteVariableType, c_val.offset, duration}(m.indices_counts[:time])
            elseif length(v.dimensions) == 2 && v.dimensions[1] == :time
                mi_vars[(c_name,v.name)] = TimestepMatrix{concreteVariableType, c_val.offset, duration}(m.indices_counts[:time], 
                                                                                                        m.indices_counts[v.dimensions[2]])
            else
                # TODO Handle unnamed indices properly
                dim_counts = [m.indices_counts[i] for i in v.dimensions]
                mi_vars[(c_name,v.name)] = Array{concreteVariableType,length(v.dimensions)}(dim_counts...)
            end
        end
    end

    return mi_vars
end

function instantiate_components(m::Model, 
                                mi_components::OrderedDict{Symbol, ComponentInstanceInfo},
                                mi_connections::Vector{InternalParameterConnection}, duration)
    builtComponents = OrderedDict{Symbol, ComponentInstance}()
    offsets = Array{Int, 1}()
    final_times = Array{Int, 1}()

    # loop over ComponentInstanceInfos, including new ConnectorComps, in order.
    for c in values(mi_components) 
        ext_connections = filter(x->x.component_name==c.name, m.external_parameter_connections)
        ext_params = map(x->x.param_name, ext_connections)
        # ext_params = Dict(x.param_name => x.external_parameter for x in ext_connections)

        int_connections = filter(x->x.target_component_name==c.name, mi_connections)
        int_params = Dict(x.target_parameter_name => x for x in int_connections)

        # TBD: modify this to create a ComponentInstance, something like this:
        #  ComponentInstance{ComponentInstanceVariables{VNAMES,VTYPES}, ComponentInstanceParameters{PNAMES,PTYPES}}
        constructor = Expr(:call, c.component_type, m.numberType, 
                           :(Val{$(c.offset)}), :(Val{$duration}), :(Val{$(c.final)}))

        # for each parameter of component c, add the offset and duration as a parametric type to the 
        # constructor call for the component.
        for (pname, p) in get_parameters(m, c)
            if 0 < length(p.dimensions) <= 2 && p.dimensions[1] == :time
                #
                # TBD: The special case of :input needs documentation!
                #
                if pname == :input2 && (c.component_type == ConnectorCompVector || c.component_type == ConnectorCompMatrix)
                    offset = c.offset
                elseif pname in ext_params
                    offset = getoffset(m.external_parameters[pname].values)
                elseif pname in keys(int_params)
                    offset = mi_components[int_params[pname].source_component_name].offset
                else
                    error("unset parameter $pname; should be caught earlier")
                end
                push!(constructor.args, :(Val{$offset}))
                push!(constructor.args, :(Val{$duration}))
            end
        end

        push!(constructor.args, m.indices_counts)
        println("\nConstructor: $constructor")

        comp = eval(eval(constructor))
        println("Comp: $comp")

        # TBD: this fails because components are not ComponentInstances, but are the 
        # old form, e.g., ::_mimi_implementation_Foo.FooImpl{Float64,1,1,1}, ::Symbol)
        builtComponents[c.name] = comp

        push!(offsets, c.offset)
        push!(final_times, c.final)
    end

    return builtComponents
end

# build should take a ModelDef, with a convenience method for users
# working only with Model instances, e.g., build(m::Model) = build(m.modeldef)
function build(modeldef::ModelDef)
end

function build(m::Model)    
    # check if all parameters are set
    unset = get_unconnected_parameters(m)
    if !isempty(unset)
        msg = "Cannot build model; the following parameters are unset: "
        for p in unset
            msg = string(msg, p, " ")
        end
        error(msg)
    end

    # Internal connections that the ModelInstance will know about.
    mi_connections = Array{InternalParameterConnection, 1}() 
    
    # Ordered list of components (including hidden ConnectorComps) that the ModelInstance will use.
    mi_components = OrderedDict{Symbol, ComponentInstanceInfo}() 
    
    # Names of external parameters that the ConnectorComps will use as their :input2 parameters.
    backups = Array{Symbol, 1}() 
    num_connector_comps = 0

    duration = getduration(m.indices_values) # for now, all components have the same duration

    # Loop through the components, adding necessary ConnectorComps and instantiating variables
    num_connector_comps = add_connector_comps(m, mi_components, mi_connections, backups)
    mi_var = instantiate_variables(m, mi_components, duration)
    
    #######################################################################
    # TBD This is where DA gave up :) Stuff above this line might work,
    # below certainly not.
    #######################################################################
    
    builtComponents = instantiate_components(m, mi_components, mi_connections, duration)

    # Make the internal parameter connections, including new hidden connections between ConnectorComps.
    for ipc in mi_connections
        c_target = builtComponents[ipc.target_component_name]
        c_source = builtComponents[ipc.source_component_name]
        setfield!(c_target.Parameters, ipc.target_parameter_name, getfield(c_source.Variables, ipc.source_variable_name))
    end

    # Make the external parameter connections.
    for x in m.external_parameter_connections
        param = m.external_parameters[x.external_parameter]
        if isa(param, ScalarModelParameter)
            setfield!(builtComponents[x.component_name].Parameters, x.param_name, param.value)
        else
            setfield!(builtComponents[x.component_name].Parameters, x.param_name, param.values)
        end
    end

    # Make the external parameter connections for the hidden ConnectorComps: connect each :input2 to its associated backup value.
    for i in 1:num_connector_comps
        setfield!(builtComponents[Symbol("ConnectorComp$i")].Parameters, :input2, m.external_parameters[backups[i]].values)
    end

    mi = ModelInstance(builtComponents, mi_connections, offsets, final_times)

    return mi
end
