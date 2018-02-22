# Create the run_timestep function for this component
function define_run_func(compdef::ComponentDef)
    @eval($(run_expr(compdef)))
end


function add_connector_comps!(md::ModelDef, backups::Vector{Symbol})
    comp_defs  = md.comp_defs
    # mi_conns::Vector{InternalParameterConnection}

    connector_count = 0

    for comp_def in compdefs(md)
        comp_name = name(comp_def)

        # first need to see if we need to add any connector components for this component
        internal_conns  = filter(x -> x.dst_comp_name == comp_name, internal_param_conns(md))
        need_conn_comps = filter(x -> (x.backup != nothing), internal_conns)

        for conn in need_conn_comps
            connector_count += 1
            push!(backups, conn.backup)
            num_dims = length(size(external_param(md, conn.backup)))

            #
            # TBD: need to instantiate a ComponentInstance
            #
            if num_dims in (1, 2)
                conn_name = num_dims == 1 ? :ConnectorCompVector : :ConnectorCompMatrix
                conn_comp_def = compdef(conn_name)

                conn_comp = ComponentDef(conn_comp_id, conn_name, conn.offset, comp_def.final)

                # TBD: do this rather than creating an instance?
                # addcomponent(md, comp_def::ComponentDef;
                #     start=nothing, final=nothing, before=nothing, after=nothing)

            else
                error("Connector components for parameters with more than two dimensions not implemented.")
            end

            conn_comp_name = Symbol("ConnectorComp$connector_count")
            mi_comps[conn_comp_name] = conn_comp # add the ConnectorComp to the ordered list of components

            # add a connection between src_component and the ConnectorComp
            push!(mi_conns, InternalParameterConnection(conn.src_var_name, conn.src_comp_name, 
                                                        :input1, conn_comp_name, conn.ignoreunits))

            # add a connection between ConnectorComp and dst_component
            push!(mi_conns, InternalParameterConnection(:output, conn_comp_name, conn.dst_param_name, 
                                                        conn.dst_comp_name, conn.ignoreunits))
        end

        # Now add the other InternalParameterConnections to the list of connections.
        for conns in setdiff(internal_conns, need_connector_comps)
            push!(mi_conns, conns)
        end

        # Order is imperative: this component is added after any ConnectorComps were added.
        # addcomponent(md, comp_def)
        mi_comps[comp_name] = comp_def
    end

    return connector_count
end


# Create the Ref or Array that will hold the value(s) for a Parameter or Variable
function instantiate_datum(md::ModelDef, offset, def::DatumDef)
    datatype = datatype(md, def)
    dims = dimensions(def)
    num_dims = length(dims)
    duration = duration(md)
    
    if num_dims == 0
        value = Ref{datatype}()

    elseif num_dims == 1 && dims[1] == :time
        value = TimestepVector{datatype, offset, duration}(indexcount(md, :time))

    elseif num_dims == 2 && dims[1] == :time
        value = TimestepMatrix{datatype, offset, duration}(indexcount(md, :time), indexcount(md, dims[2]))
    else
        # TODO Handle unnamed indices properly
        dim_counts = [indexcount(md, i) for i in dims]
        value = Array{datatype, length(dims)}(dim_counts...)
    end

    return value
end

# Return the parameterized types for parameters and variables for 
# the given component.
function _datum_types(md::ModelDef, comp_def::ComponentDef)
    var_defs = variables(comp_def)
    par_defs = parameters(comp_def)

    vnames = Tuple([name(vdef) for vdef in var_defs])
    pnames = Tuple([name(pdef) for pdef in par_defs])

    vtypes = Tuple{[datatype(md, vdef) for vdef in var_defs]...}
    ptypes = Tuple{[datatype(md, pdef) for pdef in par_defs]...}

    vars_type = ComponentInstanceVariables{vnames, vtypes}
    pars_type = ComponentInstanceParameters{pnames, ptypes}
    
    return (vars_type, pars_type)
end

# Instantiate a single component
function instantiate_component(md::ModelDef, comp_def::ComponentDef)
    comp_name = name(comp_def)
    offset = 0 # offset(comp_def) # TBD: compute offset for the comp or per variable?
    
    (vars_type, pars_type) = _datum_types(md, comp_def)
    
    var_vals = [instantiate_datum(md, offset, vdef) for vdef in variables(comp_def)]
    par_vals = [instantiate_datum(md, offset, pdef) for pdef in parameters(comp_def)]

    comp_inst = ComponentInstance(comp_def, vars_type(var_vals), pars_type(par_vals), name=comp_name)
    return comp_inst
end

function _finish_building_component(md::ModelDef, comp_inst::ComponentInstance, mi_conns::Vector{InternalParameterConnection})
    mi_comps = compdefs(md)
    mi_conns = internal_param_conns(md)
    comp_id = comp_inst.comp_id

    ext_connections = filter(x->x.comp_id == comp_id, external_param_conns(md))
    ext_params = map(x->x.param_name, ext_connections)

    int_connections = filter(x->x.dst_comp_id == comp_id, mi_conns)
    int_params = Dict(x.dst_param_name => x for x in int_connections)

    duration = duration(md)
    
    # TBD: deal with the bits below

    # for each parameter of component c, add the offset and duration as a parametric type to the 
    # constructor call for the component.
    for (pname, p) in parameters(comp_def)
        if 0 < length(p.dimensions) <= 2 && p.dimensions[1] == :time
            # TBD: document :input2
            if pname == :input2 && (comp_name in (:ConnectorCompMatrix, :ConnectorCompVector))
                offset = comp.offset

            elseif pname in ext_params
                offset = getoffset(external_param_values(pname))

            elseif (pname, p) in int_params
                offset = mi_comps[p.src_comp_id].offset

            else
                error("unset parameter $pname; should be caught earlier")
            end
        end
    end

    return comp_inst
end

function instantiate_components(mi::ModelInstance)
    md = modeldef(mi)
    
    conns = nothing   # TBD: deal with conns

    # loop over components, including new ConnectorComps, in order.
    for (comp_name, comp_def) in compdefs(md)
        comp_inst = instantiate_component(comp_def) #, comp_name)  # use the name key, which may differ from "original" name
        # comp_inst = instantiate_component(comp_inst, conns)
        addcomponent(mi, comp_inst)

        # convert to functional API
        push!(mi.offsets, comp_inst.offset)
        push!(mi.final_times, comp_inst.final)
        addcomponent(mi, comp_inst)
    end
end

function build!(m::Model)
    m.mi = build!(m.md)
    return m.mi
end

function build!(md::ModelDef)
    # check if all parameters are set
    not_set = unconnected_params(md)
    if ! isempty(not_set)
        msg = "Cannot build model; the following parameters are not set: "
        for p in not_set
            msg = string(msg, p, " ")
        end
        error(msg)
    end

    mi = ModelInstance(md)
    
    # Names of external parameters that the ConnectorComps will use as their :input2 parameters.
    backups = Vector{Symbol}() 
    num_connector_comps = 0

    # Loop through the components to add necessary ConnectorComps
    num_connector_comps = add_connector_comps!(md, backups)

    #######################################################################
    # TBD This is where DA gave up :) Stuff above this line might work,
    # below certainly not.
    #######################################################################
    
    built_comps = instantiate_components(md, duration)

    offsets = Vector{Int}()
    final_times = Vector{Int}()

    for comp in built_comps
        push!(offsets,     comp.offset)
        push!(final_times, comp.final)
    end

    # Make the internal parameter connections, including new hidden connections between ConnectorComps.
    for ipc in mi_connections
        dst_comp = built_comps[ipc.dst_comp_name]
        src_comp = built_comps[ipc.src_comp_name]
        param_name = ipc.dst_param_name
        var_name = ipc.src_var_name
        value = get_parameter_value(src_comp, var_name)
        set_parameter_value(dst_comp, param_name, value)
    end

    # Make the external parameter connections.
    for x in external_param_conns(m)
        param = external_param(m, x.external_parameter)
        comp = built_comps[x.comp_name]
        set_parameter_value(comp, x.param_name, value(param))
    end

    # Make the external parameter connections for the hidden ConnectorComps: connect each :input2 to its associated backup value.
    for i in 1:num_connector_comps
        comp_name = Symbol("ConnectorComp$i")
        param = external_param(md, backups[i])
        set_parameter_value(built_comps[comp_name], :input2, value(param))
    end

    return mi
end
