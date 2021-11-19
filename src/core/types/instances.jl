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


# Superclass for both LeafComponentInstance and CompositeComponentInstance.
# This allows the former to be type-parameterized and the latter to not be.
@class mutable ComponentInstance <: MimiClass begin
    comp_name::Symbol
    comp_id::ComponentId
    comp_path::ComponentPath
    first::Union{Nothing, Int}
    last::Union{Nothing, Int}

    function ComponentInstance(self::AbstractComponentInstance,
                               comp_def::AbstractComponentDef,
                               time_bounds::Tuple{Int,Int},
                               name::Symbol=nameof(comp_def))
        self.comp_name = name
        self.comp_id = comp_id = comp_def.comp_id
        self.comp_path = comp_def.comp_path

        # If first or last is `nothing`, substitute first or last time period
        self.first = @or(comp_def.first, time_bounds[1])
        self.last  = @or(comp_def.last,  time_bounds[2])
    end

    function ComponentInstance(comp_def::AbstractComponentDef,
                               time_bounds::Tuple{Int,Int},
                               name::Symbol=nameof(comp_def))
        self = new()
        return ComponentInstance(self, comp_def, time_bounds, name)
    end
end

@class mutable LeafComponentInstance{TV <: ComponentInstanceVariables,
                                     TP <: ComponentInstanceParameters} <: ComponentInstance begin
    variables::TV                   # TBD: write functions to extract these from type instead of storing?
    parameters::TP
    init::Union{Nothing, Function}
    run_timestep::Union{Nothing, Function}

    function LeafComponentInstance(self::AbstractComponentInstance,
                                   comp_def::AbstractComponentDef,
                                   vars::TV, pars::TP,
                                   time_bounds::Tuple{Int,Int},
                                   name::Symbol=nameof(comp_def)) where
                                {TV <: ComponentInstanceVariables,
                                 TP <: ComponentInstanceParameters}

        # superclass initializer
        ComponentInstance(self, comp_def, time_bounds, name)

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

function LeafComponentInstance(comp_def::AbstractComponentDef, vars::TV, pars::TP,
                               time_bounds::Tuple{Int,Int},
                               name::Symbol=nameof(comp_def)) where
        {TV <: ComponentInstanceVariables, TP <: ComponentInstanceParameters}

    self = LeafComponentInstance{TV, TP}()
    return LeafComponentInstance(self, comp_def, vars, pars, time_bounds, name)
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

@class mutable CompositeComponentInstance <: ComponentInstance begin
    comps_dict::OrderedDict{Symbol, AbstractComponentInstance}
    variables::NamedTuple
    parameters::NamedTuple

    function CompositeComponentInstance(self::AbstractCompositeComponentInstance,
                                        comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        variables::NamedTuple, 
                                        parameters::NamedTuple,
                                        name::Symbol=nameof(comp_def))

        comps_dict = OrderedDict{Symbol, AbstractComponentInstance}()
        for ci in comps
            comps_dict[ci.comp_name] = ci
        end

        ComponentInstance(self, comp_def, time_bounds, name)
        CompositeComponentInstance(self, comps_dict, variables, parameters)
        return self
    end

    # TBD: Construct vars and params from sub-components
    function CompositeComponentInstance(comps::Vector{<: AbstractComponentInstance},
                                        comp_def::AbstractCompositeComponentDef,
                                        time_bounds::Tuple{Int,Int},
                                        variables::NamedTuple, 
                                        parameters::NamedTuple,
                                        name::Symbol=nameof(comp_def))
        CompositeComponentInstance(new(), comps, comp_def, time_bounds, variables, parameters, name)
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
@class ModelInstance <: CompositeComponentInstance begin
    md::ModelDef
end
