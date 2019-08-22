using Classes
using DataStructures

"""
    @or(args...)

Return `a` if a !== nothing, else return `b`. Evaluates each expression
at most once.
"""
macro or(a, b)
    # @info "or($a, $b)"
    tmp = gensym(:tmp)
    expr = quote
        $tmp = $a
        ($tmp === nothing ? $b : $tmp)
    end
    esc(expr)
end

# Having all our structs/classes subtype these simplifies "show" methods
abstract type MimiStruct end
@class MimiClass <: Class

const AbstractMimiType = Union{MimiStruct, AbstractMimiClass}

#
# TBD: eliminate module_name in favor of module_path
#
# To identify components, @defcomp creates a variable with the name of
# the component whose value is an instance of this type.
struct ComponentId <: MimiStruct
    module_path::Union{Nothing, NTuple{N, Symbol} where N}
    module_name::Symbol
    comp_name::Symbol
end

ComponentId(module_name::Symbol, comp_name::Symbol) = ComponentId(nothing, module_name, comp_name)

ComponentId(m::Module, comp_name::Symbol) = ComponentId(fullname(m), nameof(m), comp_name)

# ComponentPath identifies the path through multiple composites to a leaf comp.
struct ComponentPath <: MimiStruct
    names::NTuple{N, Symbol} where N
end

ComponentPath(names::Vector{Symbol}) = ComponentPath(Tuple(names))
ComponentPath(names::Vararg{Symbol}) = ComponentPath(Tuple(names))

ComponentPath(path::ComponentPath, name::Symbol) = ComponentPath(path.names..., name)

ComponentPath(path1::ComponentPath, path2::ComponentPath) = ComponentPath(path1.names..., path2.names...)

ComponentPath(::Nothing, name::Symbol) = ComponentPath(name)

const ParamPath = Tuple{ComponentPath, Symbol}

#
# Dimensions
#

abstract type AbstractDimension <: MimiStruct end

const DimensionKeyTypes   = Union{AbstractString, Symbol, Int, Float64}
const DimensionRangeTypes = Union{UnitRange{Int}, StepRange{Int, Int}}

struct Dimension{T <: DimensionKeyTypes} <: AbstractDimension
    dict::OrderedDict{T, Int}

    function Dimension(keys::Vector{T}) where {T <: DimensionKeyTypes}
        dict = OrderedDict(collect(zip(keys, 1:length(keys))))
        return new{T}(dict)
    end

    function Dimension(rng::T) where {T <: DimensionRangeTypes}
        return Dimension(collect(rng))
    end

    Dimension(i::Int) = Dimension(1:i)

    # Support Dimension(:foo, :bar, :baz)
    function Dimension(keys::T...) where {T <: DimensionKeyTypes}
        vector = [key for key in keys]
        return Dimension(vector)
    end
end

#
# Simple optimization for ranges since indices are computable.
# Unclear whether this is really any better than simply using
# a dict for all cases. Might scrap this in the end.
#
mutable struct RangeDimension{T <: DimensionRangeTypes} <: AbstractDimension
    range::T
 end
