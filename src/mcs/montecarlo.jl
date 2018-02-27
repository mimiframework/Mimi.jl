# Python version created in 2012.
# Ported to julia in January, 2018.
#
# Author: Rich Plevin
#
# Copyright (c) 2012-2018. The Regents of the University of California (Regents)
# and Richard Plevin. See the file COPYRIGHT.txt for details.
#
# Implements the Latin Hypercube Sampling technique as described by Iman and Conover, 1982,
# including correlation control both for no correlation or for a specified rank correlation
# matrix for the sampled parameters.
#
# Heavily modified from http://nullege.com/codes/show/src@m@o@model-builder-HEAD@Bayes@lhs.py
using CSV
using StatsBase
using DataFrames
using Distributions
using MacroTools

# Add missing constructor. [Yes, this is Type Piracy; this obvious constructor
# definition will be deleted here after it is added to DataFrames proper.]
function DataFrames.DataFrame(m::Matrix{T}, cnames::AbstractArray{Symbol,1}) where T
    df = DataFrame(m)
    names!(df, cnames)
    return df
end

abstract type AbstractRandomVariable end

"""
Global dictionary of random variables. This global will disappear eventually,
as the dictionary will be defined per model.

N.B. We can't declare this Dict{Symbol, RandomVariable} since this would
require a forward type declaration, which isn't possible currently. Thus
the definition of AbstractRandomVariable.
"""
global const rvDict = Dict{Symbol, AbstractRandomVariable}()

function get_random_variable(name::Symbol)
    return rvDict[name]
end

"""
A RandomVariable can be "assigned" to different model parameters. Its
value can be used directly or applied by adding to, or multiplying by, 
reference values for the indicated parameter. Note that the distribution
must be instantiated, e.g., call as RandomVariable(:foo, Normal()), not
RandomVariable(:foo, Normal).
"""
struct RandomVariable <: AbstractRandomVariable
    name::Symbol
    dist::Distribution   

    function RandomVariable(name::Symbol, dist::Distribution)
        self = new(name, dist)
        rvDict[name] = self
        return self
    end
end

"""
    rank_corr_coef(m::Matrix{Float64})

Take a 2-D array of values and produce a array of rank correlation
coefficients representing the rank correlations pairs of columns.
"""
function rank_corr_coef(m::Matrix{Float64})
    cols = size(m, 2)
    corrCoef = eye(cols)    # identity matrix

    for i in 1:cols
        for j in (i + 1):cols
            corr = corspearman(m[:, i], m[:, j])
            corrCoef[i, j] = corrCoef[j, i] = corr
        end
    end

    return corrCoef
end

"""
    gen_rank_values(params::Int, trials::Int, corrmatrix::Matrix{Float64})

Generate a data set of 'trials' ranks for 'params'
parameters that obey the given correlation matrix.

params: number of parameters.
trials: number of trials.
corrmatrix: rank correlation matrix for parameters.
corrmatrix[i,j] denotes the rank correlation between parameters
i and j.

Output is a Matrix with 'trials' rows and 'params' columns.
The i'th column represents the ranks for the i'th parameter.
"""
function gen_rank_values(params::Int, trials::Int, corrmatrix::Matrix{Float64})
    # Create van der Waarden scores
    strata = collect(1.0:trials) / (trials + 1)
    vdwScores = quantile.(Normal(), strata)

    S = zeros(trials, params)
    for i in 1:params
        shuffle!(vdwScores)
        S[:, i] = vdwScores
    end

    P = Matrix(cholfact(corrmatrix)[:L])
    E = rank_corr_coef(S)
    Q = Matrix(cholfact(E)[:L])
    final = (S * inv(Q)') * P'

    ranks = zeros(Int, trials, params)
    for i in 1:params
        ranks[:, i] = ordinalrank(final[:, i])
    end

    return ranks
end

"""
    getPercentiles(trials::Int)

Generate a list of 'trials' values, one from each of 'trials' equal-size
segments from a uniform distribution. These are used with an RV's ppf
(percent point function = inverse cumulative function) to retrieve the
values for that RV at the corresponding percentiles.
"""
function getPercentiles(trials::Int)
    segmentSize = 1.0 / trials
    points = rand(Uniform(), trials) * segmentSize + collect(0:trials-1) * segmentSize
    return points
end

"""
    lhs(rvlist::Vector{RandomVariable}, trials::Int64; corrmatrix::Union{Matrix{Float64},Void}=nothing, asDataFrame::Bool=true)
             
Produce an array or DataFrame of 'trials' rows of values for the given parameter
list, respecting the correlation matrix 'corrmatrix' if one is specified, using Latin
Hypercube (stratified) sampling.

The values in the i'th column are drawn from the ppf function of the i'th parameter
from rvlist, and each columns i and j are rank correlated according to corrmatrix[i,j].

rvlist: (list of rv-like objects representing parameters) Only requirement
       on parameter objects is that they must implement the ppf function.

trials: (int) number of trials to generate for each parameter.

corrmatrix: a numpy matrix representing the correlation between the parameters.
       corrmatrix[i,j] should give the correlation between the i'th and j'th
       entries of rvlist.

columns: (None or list(str)) Column names to use to return a DataFrame.

skip: (list of params)) Parameters to process later because they are
       dependent on other parameter values (e.g., they're "linked"). These
       cannot be correlated.

Returns DataFrame with `trials` rows of values for the `rvlist`.
"""
function lhs(rvlist::Vector{RandomVariable}, trials::Int64; 
             corrmatrix::Union{Matrix{Float64},Void}=nothing,
             asDataFrame::Bool=true)

    ranks = corrmatrix == nothing ? nothing : gen_rank_values(length(rvlist), trials, corrmatrix)

    samples = zeros(trials, length(rvlist))

    for (i, rv) in enumerate(rvlist)
        values = quantile.(rv.dist, getPercentiles(trials))  # extract values from the RV for these percentiles

        if corrmatrix == nothing
            shuffle!(values)           # randomize the stratified samples
        else
            indices = ranks[:, i]
            values = values[indices]   # reorder to respect correlations
        end

        samples[:, i] = values
    end

    return asDataFrame ? DataFrame(samples, map(rv->rv.name, rvlist)) : samples
end

"""
    lhs_amend!(df::DataFrame, rvlist::Vector{RandomVariable}, trials::Int)

Amend the DataFrame with LHS data by adding columns for the given parameters.
This allows "linked" parameters to refer to the values of other parameters.

df: Generated by prior call to LHS or something similar.

rvlist: The random variables to fill in the df with

trials: the number of trials to generate for each parameter
"""
function lhs_amend!(df::DataFrame, rvlist::Vector{RandomVariable}, trials::Int)
    for rv in rvlist
        values = quantile.(rv.dist, getPercentiles(trials))  # extract values from the RV for these percentiles
        shuffle!(values)                                     # randomize the stratified samples
        df[rv.name] = values
    end
    return nothing
end

const CorrelationSpec = Tuple{Symbol, Symbol, Float64}

# const TransformSpec = Tuple{Symbol, Symbol, Symbol, Any}    # (paramname, {=,+=,*=}, rvname)

struct TransformSpec
    paramname::Symbol
    op::Symbol
    rvname::Symbol
    dims::Vector{Any}

    function TransformSpec(paramname::Symbol, op::Symbol, rvname::Symbol, dims::Vector{Any})
        if ! (op in (:(=), :(+=), :(*=)))
            error("Valid operators are =, +=, and *= (got $op)")
        end
        return new(paramname, op, rvname, dims)
    end
    
end

function TransformSpec(paramname::Symbol, op::Symbol, rvname::Symbol)
    return TransformSpec(paramname, op, rvname, [])
end

"""
Holds all the data that defines a Monte Carlo simulation.
"""
mutable struct MonteCarloSimulation
    trials::Int64
    rvlist::Vector{RandomVariable}
    translist::Vector{TransformSpec}
    corrlist::Union{Vector{CorrelationSpec}, Void}
    savelist::Vector{Any}
    data::DataFrame

    function MonteCarloSimulation(rvlist::Vector{RandomVariable}, 
                                  translist::Vector{TransformSpec}, 
                                  corrlist::Union{Vector{CorrelationSpec}, Void},
                                  savelist::Vector{Any})
        return new(0, rvlist, translist, corrlist, savelist, DataFrame())
    end
end

"""
    correlation_matrix(mcs::MonteCarloSimulation)

Return a Matrix holding the correlations between random variables
as indicated in the MonteCarloSimulation, or nothing if no correlations
have been defined.

TBD: if needed, compute correlation matrix only for correlated
     RVs, leaving all uncorrelated RVs alone.
"""
function correlation_matrix(mcs::MonteCarloSimulation)
    if length(mcs.corrlist) == 0
        return nothing
    end

    # create a mapping of names to RV position in list
    names = Dict([(rv.name, i) for (i, rv) in enumerate(mcs.rvlist)])

    count = length(mcs.rvlist)
    corrmatrix = eye(count, count)

    for (name1, name2, value) in mcs.corrlist
        i = names[name1]
        j = names[name2]
        corrmatrix[i, j] = corrmatrix[j, i] = value
    end

    return corrmatrix
end

function save_trial_data(mcs::MonteCarloSimulation, filename::String)
    CSV.write(filename, mcs.data)
    return nothing
end

"""
    generate_trials!(mcs::MonteCarloSimulation, trials::Int64; filename::String="")

Generate the given number of trials for the given MonteCarloSimulation instance.
"""
function generate_trials!(mcs::MonteCarloSimulation, trials::Int64; filename::String="")
    corrmatrix = correlation_matrix(mcs)
    mcs.data = lhs(mcs.rvlist, trials, corrmatrix=corrmatrix)
    mcs.trials = trials

    if filename != ""
        save_trial_data(mcs, filename)
    end
end


macro defmcs(expr)
    @capture(expr, elements__)
    _rvs::Vector{RandomVariable} = []
    _corrs::Vector{CorrelationSpec} = []
    _transforms::Vector{TransformSpec} = []
    _saves::Vector{Any} = []

    # distill into a function since it's called from two branches below
    function saverv(rvname, distname, distargs)
        println("saverv($rvname, $distname, $distargs)")
        args = Tuple(distargs)
        push!(_rvs, RandomVariable(rvname, eval(distname)(args...)))
    end

    for elt in elements
        # Meta.show_sexpr(elt)
        # println("")
        # e.g.,  rv(name1) = Normal(10, 3)
        if @capture(elt, rv(rvname_) = distname_(distargs__))
            saverv(rvname, distname, distargs)

        elseif @capture(elt, save(vars__))
            t = typeof(vars)
            println("Vars to save: $vars, type is $t")
            push!(_saves, vars)

        # e.g., name1:name2 = 0.7
        elseif @capture(elt, name1_:name2_ = value_)
            push!(_corrs, (name1, name2, value))

        # e.g., ext_var5[2010:2050, :] *= name2
        # A bug in Macrotools prevents this shorter expression from working:
        # elseif @capture(elt, ((extvar_  = rvname_Symbol) | 
        #                       (extvar_ += rvname_Symbol) |
        #                       (extvar_ *= rvname_Symbol) |
        #                       (extvar_  = distname_(distargs__)) | 
        #                       (extvar_ += distname_(distargs__)) |
        #                       (extvar_ *= distname_(distargs__))))
        elseif (@capture(elt, extvar_  = rvname_Symbol) ||
                @capture(elt, extvar_ += rvname_Symbol) ||
                @capture(elt, extvar_ *= rvname_Symbol) ||
                @capture(elt, extvar_  = distname_(distargs__)) ||
                @capture(elt, extvar_ += distname_(distargs__)) ||
                @capture(elt, extvar_ *= distname_(distargs__)))
            # For "anonymous" RVs, e.g., ext_var2[2010:2100, :] *= Uniform(0.8, 1.2), we
            # gensym a name and process it as a named RV (as above), then use the generated
            # symbol. This keeps the structure consistent internally.
            if rvname == nothing
                rvname = gensym("rv")
                saverv(rvname, distname, distargs)
            end

            op = elt.head
            if @capture(extvar, name_[args__])
                # println("Ref:  $name, $args")               
                # Meta.show_sexpr(extvar)
                # println("")

                # if extvar.head == :ref, extvar.args must be one of:
                # - a scalar value, e.g., name[2050] => (:ref, :name, 2050)
                #   convert to tuple of dimension specifiers (:name, 2050)
                # - a slice expression, e.g., name[2010:2050] => (:ref, :name, (:(:), 2010, 2050))
                #   convert to (:name, 2010:2050) [convert it to actual UnitRange instance]
                # - a tuple of symbols, e.g., name[(US, CHI)] => (:ref, :name, (:tuple, :US, :CHI))
                #   convert to (:name, (:US, :CHI))
                # - combinations of these, e.g., name[2010:2050, (US, CHI)] => (:ref, :name, (:(:), 2010, 2050), (:tuple, :US, :CHI))
                #   convert to (:name, 2010:2050, (:US, :CHI))
                dims = Vector{Any}()
                for arg in args
                    # println("Arg: $arg")
                    if @capture(arg, i_Int)  # scalar (must be integer)
                        dim = i
                    elseif @capture(arg, i_Int:j_Int)  # range
                        dim = i:j
                    elseif @capture(arg, s_Symbol)
                        dim = s
                    elseif isa(arg, Expr) && arg.head == :tuple  # tuple of Symbols (@capture didn't work...)
                        dim = arg.args
                    else
                        error("Unrecognized stochastic parameter specification: $arg")
                    end
                    push!(dims, dim)
                    # println("dims = $dims")
                end
                push!(_transforms, TransformSpec(name, op, rvname, dims))
            else
                push!(_transforms, TransformSpec(extvar, op, rvname))
            end
        else
            error("Unrecognized expression '$elt' in @defmcs")
        end
    end
    return MonteCarloSimulation(_rvs, _transforms, _corrs, _saves)
end

"""
    perturb_parameters(mi::ModelInstance, mcs::MonteCarloSimulation, trialnum::Int64)

TBD:
"""
function perturb_parameters(mi::ModelInstance, mcs::MonteCarloSimulation, trialnum::Int64)
    if trialnum > length(mcs.trials)
        error("Attempted to run trial $trial, but only $(mcs.trials) trials are defined")
    end

    rvlist = mcs.rvlist
    df = mcs.data

    # MI needs ref back to Model
    extparams = mi.model.external_parameters       # Dict{global_name, Union{ScalarModelParameter,ArrayModelParameter}}

    for (paramspec, op, rvname) in mcs.transforms

    end
end

"""
    runmcs(mi::ModelInstance, mcs::MonteCarloSimulation, trials::Vector{Int64})

Run the indicated trials.
TBD: Have MonteCarloSimulation store a reference to Model?
"""
function runmcs(mi::ModelInstance, mcs::MonteCarloSimulation, trials::Vector{Int64})
    for trialnum in trials
        perturb_parameters(mi, mcs, trialnum)
    end
end
