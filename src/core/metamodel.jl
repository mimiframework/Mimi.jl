abstract struct MetaComponent end

struct Component <: MetaComponent
    pars::Vector{Parameter}
    vars::Vector{Variable}
    dims::Vector{Symbol}
    cd::ComponentDef
    ci::ComponentInstance
end

struct Model <: MetaComponent
    pars::Vector{ParameterInstance}       # these refer to pars/vars inside a model's comps
    vars::Vector{VariableInstance}
    dims::Vector{Symbol}
    comps::Vector{MetaComponent}
    mi::union{ModelInstance, Void}
    md::ModelDef

    function new(md::ModelDef)
        m = Model(md)
        m.mi = nothing
        m.comps = Vector{MetaComponent}()          # compute these when the model is built
        m.pars  = Vector{ParameterInstance}()
        m.vars  = Vector{VariableInstance}()
        m.vars  = Vector{VariableInstance}()
        return m
    end
end

#
# These funcs provide the API to MetaComponents
#

variables(c::Component) = variables(c.ci)

variables(m::Model) = variables(m.params)


parameters(c::Component) = parameters(c.ci)

parameters(m::Model) = parameters(m.vars)


components(m::Model) = components(m.mi) # should already be a @modelegate for this

components(c::Component) = []


build(c::Component) = nothing

function build(m::Model)
    for c in components(m)
        (vars, pars, dims) = build(c)

        # Add vars, pars, dims to our list
    end

    m.mi = build(m.md)

    return # vars, pars, dims
end


reset(c::Component) = reset(c.ci)

function reset(m::Model)
    for c in components(m)
        reset(c)
    end    
end


run_timestep(c::Component, args...) = c.ci.run_timestep(args...)

function run_timestep(m::Model)
    for c in components(m)
        run_timestep(c)
    end    
end
