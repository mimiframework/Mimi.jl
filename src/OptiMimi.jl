module OptiMimi

using NLopt

import Mimi: Model, CertainScalarParameter, CertainArrayParameter, addparameter

export problem, solution

allverbose = false

type OptimizationProblem
    model::Model
    components::Vector{Symbol}
    names::Vector{Symbol}
    opt::Opt
    constraints::Vector{Function}
end

"""Returns (ii, len, isscalar) with the index of each symbol and its length."""
function nameindexes(model::Model, names::Vector{Symbol})
    ii = 1
    for name in names
        if isa(model.parameters[name], CertainScalarParameter)
            produce((ii, 1, true))
        elseif isa(model.parameters[name], CertainArrayParameter)
            produce((ii, length(model.parameters[name].values), false))
        else
            error("Unknown parameter type for " + string(name))
        end
        ii += 1
    end
end

"""Set parameters in a model."""
function setparameters(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, xx::Vector)
    startindex = 1
    for (ii, len, isscalar) in @task nameindexes(model, names)
        if isscalar
            setfield!(model.components[components[ii]].Parameters, names[ii], xx[startindex])
        else
            setfield!(model.components[components[ii]].Parameters, names[ii], xx[startindex:(startindex+len - 1)])
        end
        startindex += len
    end
end

"""Setup an optimization problem."""
function problem{T<:Real}(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, lowers::Vector{T}, uppers::Vector{T}, objective::Function; constraints::Vector{Function}=Function[], algorithm::Symbol=:LN_COBYLA)
    my_lowers = T[]
    my_uppers = T[]

    ## Replace with eachname
    totalvars = 0
    for (ii, len, isscalar) in @task nameindexes(model, names)
        append!(my_lowers, [lowers[ii] for jj in 1:len])
        append!(my_uppers, [uppers[ii] for jj in 1:len])
        totalvars += len
    end

    function my_objective(xx::Vector, grad::Vector)
        if allverbose
            println(xx)
        end

        setparameters(model, components, names, xx)

        run(model)
        objective(model)
    end

    opt = Opt(algorithm, totalvars)
    lower_bounds!(opt, my_lowers)
    upper_bounds!(opt, my_uppers)
    xtol_rel!(opt, minimum(1e-6 * (uppers - lowers)))

    max_objective!(opt, my_objective)

    for constraint in constraints
        let this_constraint = constraint
            function my_constraint(xx::Vector, grad::Vector)
                setparameters(model, components, names, xx)
                this_constraint(model)
            end

            inequality_constraint!(opt, my_constraint)
        end
    end

    OptimizationProblem(model, components, names, opt, constraints)
end

"""Solve an optimization problem."""
function solution(optprob::OptimizationProblem, generator::Function; maxiter=Inf, verbose=false)
    global allverbose
    allverbose = verbose

    if verbose
        println("Selecting an initial point.")
    end

    attempts = 0
    initial = []
    valid = false
    while attempts < maxiter
        initial = generator()

        setparameters(optprob.model, optprob.components, optprob.names, initial)

        valid = true
        for constraint in optprob.constraints
            if constraint(optprob.model) >= 0
                valid = false
                break
            end
        end

        if valid
            break
        end

        attempts += 1
    end

    if !valid
        throw(DomainError("Could not find a valid initial value."))
    end

    if verbose
        println("Optimizing...")
    end
    (minf,minx,ret) = optimize(optprob.opt, initial)

    (minf, minx)
end

end # module
