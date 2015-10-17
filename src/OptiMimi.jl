module OptiMimi

using NLopt
using ForwardDiff
using Compat

import Mimi: Model, CertainScalarParameter, CertainArrayParameter, addparameter

export problem, solution, unaryobjective

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
            model.components[components[ii]].Parameters.(names[ii]) = xx[startindex]
        else
            model.components[components[ii]].Parameters.(names[ii]) = collect(Number, xx[startindex:(startindex+len - 1)])
        end
        startindex += len
    end
end

"""Generate the form of objective function used by the optimization, taking parameters rather than a model."""
function unaryobjective(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, objective::Function)
    function my_objective(xx::Vector)
        if allverbose
            println(xx)
        end

        setparameters(model, components, names, xx)
        run(model)
        objective(model)
    end

    my_objective
end

"""Create an NLopt-style objective function which does not use its grad argument."""
function gradfreeobjective(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, objective::Function)
    myunaryobjective = unaryobjective(model, components, names, objective)
    function myobjective(xx::Vector, grad::Vector)
        myunaryobjective(xx)
    end

    myobjective
end

"""Create an NLopt-style objective function which computes an autodiff gradient."""
function autodiffobjective(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, objective::Function)
    myunaryobjective = unaryobjective(model, components, names, objective)
    if VERSION < v"0.4.0-dev"
        # Slower: doesn't use cache
        function myobjective(xx::Vector, gradout::Vector)
            gradual = myunaryobjective(GraDual(xx))
            copy!(gradout, grad(gradual))
            value(gradual)
        end
    else
        fdcache = ForwardDiffCache()
        function myobjective(xx::Vector, grad::Vector)
            calcgrad, allresults = ForwardDiff.gradient(myunaryobjective, xx, AllResults, cache=fdcache)
            copy!(grad, calcgrad)
            value(allresults)
        end
    end

    myobjective
end

function checkautodiff(model::Model, components::Vector{Symbol})
    # Note: currently checks all components, not just those affected by `components`
    if model.autodiffable
        for componentname in components
            component = model.components[componentname]
            # Check that the first parameter has type Number
            onevar = getfield(component.Variables, fieldnames(component.Variables)[1])
            if eltype(onevar) != Number
                warn("Model is set to be autodiffable, but $(componentname) is not defined with @defcompo.")
                model.autodiffable = false
                return
            end
        end
    end
end

"""Setup an optimization problem."""
function problem{T<:Real}(model::Model, components::Vector{Symbol}, names::Vector{Symbol}, lowers::Vector{T}, uppers::Vector{T}, objective::Function; constraints::Vector{Function}=Function[], algorithm::Symbol=:LN_COBYLA_OR_LD_MMA)
    my_lowers = T[]
    my_uppers = T[]

    ## Replace with eachname
    totalvars = 0
    for (ii, len, isscalar) in @task nameindexes(model, names)
        append!(my_lowers, [lowers[ii] for jj in 1:len])
        append!(my_uppers, [uppers[ii] for jj in 1:len])
        totalvars += len
    end

    checkautodiff(model, components)

    if model.autodiffable
        if algorithm == :LN_COBYLA_OR_LD_MMA
            algorithm = :LD_MMA
        end
        if string(algorithm)[2] == 'N'
            warn("Model is autodifferentiable, but optimizing using a derivative-free algorithm.")
            myobjective = gradfreeobjective(model, components, names, objective)
        else
            myobjective = autodiffobjective(model, components, names, objective)
        end
    else
        if algorithm == :LN_COBYLA_OR_LD_MMA
            algorithm = :LN_COBYLA
        elseif string(algorithm)[2] == 'D'
            warn("Model is non-differentiable, but requested a gradient algorithm; instead using LN_COBYLA.")
            algorithm = :LN_COBYLA
        end

        myobjective = gradfreeobjective(model, components, names, objective)
    end

    opt = Opt(algorithm, totalvars)
    lower_bounds!(opt, my_lowers)
    upper_bounds!(opt, my_uppers)
    xtol_rel!(opt, minimum(1e-6 * (uppers - lowers)))

    max_objective!(opt, myobjective)

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
