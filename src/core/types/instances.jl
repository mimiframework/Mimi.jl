#
# Types supporting instantiated models and their components
#

# Supertype for variables and parameters in component instances
@class ComponentInstanceData{NT <: NamedTuple} <: MimiClass begin
    nt::NT
    comp_paths::Vector{ComponentPath}   # records the origin of each datum
end

nt(obj::AbstractComponentInstanceData) = getfield(obj, :nt)
types(obj::AbstractComponentInstanceData) = typeof(nt(obj)).parameters[2].parameters
Base.names(obj::AbstractComponentInstanceData)  = keys(nt(obj))
Base.values(obj::AbstractComponentInstanceData) = values(nt(obj))

# Centralizes the shared functionality from the two component data subtypes.
function _datum_instance(subtype::Type{<: AbstractComponentInstanceData},
                         names, types, values, paths)
    # @info "_datum_instance: names=$names, types=$types"
    NT = NamedTuple{Tuple(names), Tuple{types...}}
    return subtype(NT(values), Vector{ComponentPath}(paths))
end

@class ComponentInstanceParameters <: ComponentInstanceData begin
    function ComponentInstanceParameters(nt::NT, paths::Vector{ComponentPath}) where {NT <: NamedTuple}
        return new{NT}(nt, paths)
    end

    function ComponentInstanceParameters(names::Vector{Symbol},
                                         types::Vector{DataType},
                                         values::Vector{Any},
                                         paths)
        return _datum_instance(ComponentInstanceParameters, names, types, values, paths)
    end
end

@class ComponentInstanceVariables <: ComponentInstanceData begin
    function ComponentInstanceVariables(nt::NT, paths::Vector{ComponentPath}) where {NT <: NamedTuple}
        return new{NT}(nt, paths)
    end

    function ComponentInstanceVariables(names::Vector{Symbol},
                                        types::Vector{DataType},
                                        values::Vector{Any},
                                        paths)
        return _datum_instance(ComponentInstanceVariables, names, types, values, paths)
    end
end

# A container class that wraps the dimension dictionary when passed to run_timestep()
# and init(), so we can safely implement Base.getproperty(), allowing `d.regions` etc.
struct DimValueDict <: MimiStruct
    dict::Dict{Symbol, Vector{Int}}

    function DimValueDict(dim_dict::AbstractDict)
        d = Dict([name => collect(values(dim)) for (name, dim) in dim_dict])
        new(d)
    end
end

# Special case support for Dicts so we can use dot notation on dimension.
# The run_timestep() and init() funcs pass a DimValueDict of dimensions by name
# as the "d" parameter.
Base.getproperty(obj::DimValueDict, property::Symbol) = getfield(obj, :dict)[property]

@class mutable ComponentInstance{TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters} <: MimiClass begin
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    variables::TV                   # TBD: write functions to extract these from type instead of storing?
    parameters::TP
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    init::Union{Nothing, Function}
    run_timestep::Union{Nothing, Function}

    function ComponentInstance(self::AbstractComponentInstance,
                               comp_def::AbstractComponentDef,
                               vars::TV, pars::TP,
                               time_bounds::Tuple{Int,Int},
                               name::Symbol=nameof(comp_def)) where
                {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

        self.comp_id = comp_id = comp_def.comp_id
        self.comp_path = comp_def.comp_path
        self.comp_name = name
        self.variables = vars
        self.parameters = pars

        # If first or last is `nothing`, substitute first or last time period
        self.first = @or(comp_def.first, time_bounds[1])
        self.last  = @or(comp_def.last,  time_bounds[2])

        # @info "ComponentInstance evaluating $(comp_id.module_name)"
        module_name = comp_id.module_name
        comp_module = getfield(Main, module_name)

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # CompositeComponentInstances use a standard method that just loops over inner components.
        # TBD: use FunctionWrapper here?
        function get_func(name)
            if is_composite(self)
                return nothing
            end

            func_name = Symbol("$(name)_$(nameof(comp_module))_$(self.comp_id.comp_name)")
            try
                getfield(comp_module, func_name)
            catch err
                # @info "Eval of $func_name in module $comp_module failed"
                nothing
            end
        end

        # `is_composite` indicates a ComponentInstance used to store summary
        # data for ComponentInstance and is not itself runnable.
        self.init         = get_func("init")
        self.run_timestep = get_func("run_timestep")

        return self
    end

    # Create an empty instance with the given type parameters
    function ComponentInstance{TV, TP}() where {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
        return new{TV, TP}()
    end
end

function ComponentInstance(comp_def::AbstractComponentDef, vars::TV, pars::TP,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def)) where
        {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

    self = ComponentInstance{TV, TP}()
    return ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
end

# These can be called on CompositeComponentInstances and ModelInstances
compdef(obj::AbstractComponentInstance) = compdef(comp_id(obj))
pathof(obj::AbstractComponentInstance) = obj.comp_path
has_dim(obj::AbstractComponentInstance, name::Symbol) = haskey(obj.dim_value_dict, name)
dimension(obj::AbstractComponentInstance, name::Symbol) = obj.dim_value_dict[name]
first_period(obj::AbstractComponentInstance) = obj.first
last_period(obj::AbstractComponentInstance)  = obj.last

#
# Include only exported vars and pars
#
"""
Return the ComponentInstanceParameters/Variables exported by the given list of
component instances.
"""
function _comp_instance_vars_pars(comp_def::AbstractCompositeComponentDef,
								  comps::Vector{<: AbstractComponentInstance})
    vdict = Dict([:types => [], :names => [], :values => [], :paths => []])
    pdict = Dict([:types => [], :names => [], :values => [], :paths => []])

    root = get_root(comp_def)   # to find comp_defs by path

    comps_dict = Dict([comp.comp_name => comp for comp in comps])

    for (export_name, dr) in comp_def.exports
        datum_comp = find_comp(dr)
        datum_name = nameof(dr)
        ci = comps_dict[nameof(datum_comp)]

        datum = (is_parameter(dr) ? ci.parameters : ci.variables)
        d = (is_parameter(dr) ? pdict : vdict)

        # Find the position of the desired field in the named tuple
        # so we can extract it's datatype.
        pos = findfirst(isequal(datum_name), names(datum))
        datatypes = types(datum)
        dtype = datatypes[pos]
        value = getproperty(datum, datum_name)
        
        push!(d[:names],  export_name)
        push!(d[:types],  dtype)
        push!(d[:values], value)
        push!(d[:paths],  dr.comp_path)
    end

    vars = ComponentInstanceVariables(Vector{Symbol}(vdict[:names]), Vector{DataType}(vdict[:types]), 
                                      Vector{Any}(vdict[:values]), Vector{ComponentPath}(vdict[:paths]))

    pars = ComponentInstanceParameters(Vector{Symbol}(pdict[:names]), Vector{DataType}(pdict[:types]), 
                                       Vector{Any}(pdict[:values]), Vector{ComponentPath}(pdict[:paths]))                                      
    return vars, pars
end

@class mutable CompositeComponentInstance <: ComponentInstance begin
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}

    function CompositeComponentInstance(self::AbstractCompositeComponentInstance,
                                        comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        vars::ComponentInstanceVariables,
                                        pars::ComponentInstanceParameters,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))

        comps_dict = OrderedDict{Symbol, AbstractComponentInstance}()
        for ci in comps
            comps_dict[ci.comp_name] = ci
        end

        ComponentInstance(self, comp_def, vars, pars, time_bounds, name)
        CompositeComponentInstance(self, comps_dict)
        return self
    end

    # Constructs types of vars and params from sub-components
    function CompositeComponentInstance(comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        name::Symbol=nameof(comp_def))
        (vars, pars) = _comp_instance_vars_pars(comp_def, comps)
        self = new{typeof(vars), typeof(pars)}()
        CompositeComponentInstance(self, comps, comp_def, vars, pars, time_bounds, name)
    end
end

# These methods can be called on ModelInstances as well
components(obj::AbstractCompositeComponentInstance) = values(obj.comps_dict)
has_comp(obj::AbstractCompositeComponentInstance, name::Symbol) = haskey(obj.comps_dict, name)
compinstance(obj::AbstractCompositeComponentInstance, name::Symbol) = obj.comps_dict[name]

is_leaf(ci::AbstractComponentInstance) = true
is_leaf(ci::AbstractCompositeComponentInstance) = false
is_composite(ci::AbstractComponentInstance) = !is_leaf(ci)

# ModelInstance holds the built model that is ready to be run
@class ModelInstance <: CompositeComponentInstance begin
    md::ModelDef

    # Similar to generated constructor, but extract {TV, TP} from argument.
    function ModelInstance(cci::CompositeComponentInstance{TV, TP}, md::ModelDef) where
            {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
        return ModelInstance{TV, TP}(cci, md)
    end
end
