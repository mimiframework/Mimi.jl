using DataStructures

mutable struct Timestep{Offset, Duration, Final}
	t::Int
end

mutable struct Clock
	ts::Timestep

	function Clock(offset::Int, final::Int, duration::Int)
		self = new()
		self.ts = Timestep{offset, duration, final}(1)
		return self
	end
end

abstract type ComponentInstanceData end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `p` argument. The main role of this type
# is to provide the convenient `p.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the parameters
struct ComponentInstanceParameters{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each parameter. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ComponentInstanceParameters{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `v` argument. The main role of this type
# is to provide the convenient `v.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the variables
struct ComponentInstanceVariables{NAMES,TYPES} <: ComponentInstanceData
    # This field has one element for each variable. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ComponentInstanceVariables{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# This type just bundles the values that are passed to `run_timestep` in
# one structure. We don't strictly need it, but it makes things cleaner.
struct ComponentInstance{TVARS <: ComponentInstanceVariables, 
                         TPARS <: ComponentInstanceParameters}
    comp_def::ComponentDef
    vars::TVARS
    pars::TPARS
    indices

    # TBD: Add these here and eliminate type ComponentInstanceInfo
    # offset::Int
    # final::Int
end

# This type holds the values of a built model and can actually be run.
mutable struct ModelInstance
    # model_def::ModelDef
    components::OrderedDict{Symbol, ComponentInstance}
    offsets::Vector{Int}        # in order corresponding with components
    final_times::Vector{Int}
end
