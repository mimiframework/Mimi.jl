# An instance of this type is passed to the run_timestep function of a
# component, typically as the `p` argument. The main role of this type
# is to provide the convenient `p.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the parameters
struct ModelInstanceComponentParameters{NAMES,TYPES}
    # This field has one element for each parameter. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ModelInstanceComponentParameters{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# An instance of this type is passed to the run_timestep function of a
# component, typically as the `v` argument. The main role of this type
# is to provide the convenient `v.nameofparameter` syntax.
# NAMES should be a Tuple of Symbols, namely the names of the variables
struct ModelInstanceComponentVariables{NAMES,TYPES}
    # This field has one element for each variable. The order must match
    # the order of NAMES
    # The elements can either be of type Ref (for scalar values) or of
    # some array type
    vals::TYPES

    function ModelInstanceComponentVariables{NAMES,TYPES}(values) where {NAMES,TYPES}
        return new(values)
    end
end

# This type just bundles the values that are passed to `run_timestep` in
# one structure. We don't strictly need it, but it makes things cleaner.
struct ModelInstanceComponent{TVARS,TPARS} where {TVARS<:ModelInstanceComponentVariables,TPARS<:ModelInstanceComponentParameters}
    vars::TVARS
    pars::TPARS
    indices
end

# This type holds the values of a built model and can actually be run.
mutable struct ModelInstance
    components::OrderedDict{Symbol, ModelInstanceComponent}
    offsets::Array{Int, 1} # in order corresponding with components
    final_times::Array{Int, 1}
end