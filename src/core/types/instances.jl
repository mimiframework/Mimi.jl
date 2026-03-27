#
# Types supporting instantiated models and their components
#

# Supertype for variables and parameters in component instances
struct ComponentInstanceParameters{NT <: NamedTuple} <: AbstractComponentInstanceData
    nt::NT
    comp_paths::Vector{ComponentPath}   # records the origin of each datum

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

struct ComponentInstanceVariables{NT <: NamedTuple} <: AbstractComponentInstanceData
    nt::NT
    comp_paths::Vector{ComponentPath}   # records the origin of each datum

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


# Shared initializer for ComponentInstance fields on subtypes
function _init_component_instance!(self::AbstractComponentInstance,
                                   comp_def::AbstractComponentDef,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def))
    self.comp_name = name
    self.comp_id = comp_def.comp_id
    self.comp_path = comp_def.comp_path

    # If first or last is `nothing`, substitute first or last time period
    self.first = @or(comp_def.first, time_bounds[1])
    self.last  = @or(comp_def.last,  time_bounds[2])
end

mutable struct LeafComponentInstance{TV <: ComponentInstanceVariables,
                                     TP <: ComponentInstanceParameters} <: AbstractComponentInstance
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    variables::TV                   # TBD: write functions to extract these from type instead of storing?
    parameters::TP
    init::Union{Nothing, Function}
    run_timestep::Union{Nothing, Function}

    function LeafComponentInstance(comp_def::AbstractComponentDef,
                                   vars::TV, pars::TP,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def)) where
                                {TV <: ComponentInstanceVariables,
                                 TP <: ComponentInstanceParameters}

        self = new{TV, TP}()

        # initialize base ComponentInstance fields
        _init_component_instance!(self, comp_def, time_bounds, name)

        self.variables = vars
        self.parameters = pars

        comp_module = compmodule(self)

        # The try/catch allows components with no run_timestep function (as in some of our test cases)
        # CompositeComponentInstances use a standard method that just loops over inner components.
        # TBD: use FunctionWrapper here?
        function get_func(name)

            #
            # TBD: since this class is no longer a superclass of CompositeComponentInstance
            # this test should be unnecessary. Double-check this though...
            #
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

        self.init         = get_func("init")
        self.run_timestep = get_func("run_timestep")

        return self
    end

    # Create an empty instance with the given type parameters
    function LeafComponentInstance{TV, TP}() where {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}
        return new{TV, TP}()
    end
end

# These can be called on CompositeComponentInstances and ModelInstances
compdef(obj::AbstractComponentInstance) = compdef(comp_id(obj))
Base.pathof(obj::AbstractComponentInstance) = obj.comp_path
first_period(obj::AbstractComponentInstance) = obj.first
last_period(obj::AbstractComponentInstance)  = obj.last

"""
Return the ComponentInstanceParameters/Variables exported by the given list of
component instances.
"""
function _comp_instance_vars_pars(comp_def::AbstractCompositeComponentDef,
								  comps::Vector{<: AbstractComponentInstance})
    vdict = Dict([:types => [], :names => [], :values => [], :paths => []])
    pdict = Dict([:types => [], :names => [], :values => [], :paths => []])

    comps_dict = Dict([comp.comp_name => comp for comp in comps])

    vars = ComponentInstanceVariables(Vector{Symbol}(vdict[:names]), Vector{DataType}(vdict[:types]),
                                      Vector{Any}(vdict[:values]), Vector{ComponentPath}(vdict[:paths]))

    pars = ComponentInstanceParameters(Vector{Symbol}(pdict[:names]), Vector{DataType}(pdict[:types]),
                                       Vector{Any}(pdict[:values]), Vector{ComponentPath}(pdict[:paths]))
    return vars, pars
end

mutable struct CompositeComponentInstance <: AbstractCompositeComponentInstance
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}
    variables::NamedTuple
    parameters::NamedTuple

    # TBD: Construct vars and params from sub-components
    function CompositeComponentInstance(comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        variables::NamedTuple, 
                                        parameters::NamedTuple,
                                        name::Symbol=nameof(comp_def))
        self = new()

        comps_dict = OrderedDict{Symbol, AbstractComponentInstance}()
        for ci in comps
            comps_dict[ci.comp_name] = ci
        end

        _init_component_instance!(self, comp_def, time_bounds, name)
        self.comps_dict = comps_dict
        self.variables = variables
        self.parameters = parameters
        return self
    end
end

# These methods can be called on ModelInstances as well
components(obj::AbstractCompositeComponentInstance) = values(obj.comps_dict)
has_comp(obj::AbstractCompositeComponentInstance, name::Symbol) = haskey(obj.comps_dict, name)
compinstance(obj::AbstractCompositeComponentInstance, name::Symbol) = obj.comps_dict[name]

is_leaf(ci::LeafComponentInstance) = true
is_leaf(ci::AbstractCompositeComponentInstance) = false
is_composite(ci::AbstractComponentInstance) = !is_leaf(ci)

# ModelInstance holds the built model that is ready to be run
mutable struct ModelInstance <: AbstractCompositeComponentInstance
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}
    variables::NamedTuple
    parameters::NamedTuple
    md::ModelDef
end

# Convenience constructor: wrap an existing CompositeComponentInstance with a ModelDef
function ModelInstance(ci::CompositeComponentInstance, md::ModelDef)
    return ModelInstance(ci.comp_name, ci.comp_id, ci.comp_path, ci.first, ci.last,
                         ci.comps_dict, ci.variables, ci.parameters, md)
end
