module MyModel

using Base.Test
using Mimi

@defcomp ch4forcing1 begin
    c_N2Oconcentration = Parameter(index=[time],unit="ppbv")
    c_CH4concentration = Parameter(index=[time],unit="ppbv")
    f0_CH4baseforcing = Parameter(unit="W/m2")
    fslope_CH4forcingslope = Parameter(unit="W/m2")
    c0_baseN2Oconc = Parameter(unit="ppbv")
    c0_baseCH4conc = Parameter(unit="ppbv")
    f_CH4forcing = Variable(index=[time],unit="W/m2")
    over_baseoverlap = Variable(unit="W/m2")
    over = Variable(index=[time],unit="W/m2")

    function run(p, v, d, t)
        #from p.16 in Hope 2009
        if t==1
            #calculate baseline forcing overlap in first time period
            v.over_baseoverlap = -0.47 * log(1 + 2.0e-5 * (p.c0_baseN2Oconc * p.c0_baseCH4conc)^0.75 + 5.3e-15 * p.c0_baseCH4conc * (p.c0_baseCH4conc * p.c0_baseN2Oconc)^1.52)
        end
    
        v.over[t] = -0.47 * log(1 + 2.0e-5 * (p.c_CH4concentration[t] * p.c0_baseN2Oconc)^0.75 + 5.3e-15 * p.c_CH4concentration[t] * (p.c0_baseN2Oconc * p.c_CH4concentration[t])^1.52)
        v.f_CH4forcing[t] = p.f0_CH4baseforcing + p.fslope_CH4forcingslope * (sqrt(p.c_CH4concentration[t]) - sqrt(p.c0_baseCH4conc)) + v.over[t] - v.over_baseoverlap
    end
end

@defmodel test_model begin
    index[time] = 2010:2100
    component(ch4forcing1)
    component(ch4forcing1, ch4forcing2) # add another one with a different name
end

c1 = compdef(test_model, :ch4forcing1)
c2 = compdef(test_model, :ch4forcing2)

#
# Macro expands to essentially these lines
#

# adddimension(c2, :time)

# addparameter(c2, :c_N2Oconcentration, Number, Symbol[:time], "", "ppbv")
# addparameter(c2, :c_CH4concentration, Number, Symbol[:time], "", "ppbv")
# addparameter(c2, :f0_CH4baseforcing, Number, Symbol[], "", "W/m2")
# addparameter(c2, :fslope_CH4forcingslope, Number, Symbol[], "", "W/m2")
# addparameter(c2, :c0_baseN2Oconc, Number, Symbol[], "", "ppbv")
# addparameter(c2, :c0_baseCH4conc, Number, Symbol[], "", "ppbv")

# addvariable(c2, :f_CH4forcing, Number, Symbol[:time], "", "W/m2")
# addvariable(c2, :over_baseoverlap, Number, Symbol[], "", "W/m2")
# addvariable(c2, :over, Number, Symbol[:time], "", "W/m2")


@test c2.comp_id.module_name == :MyModel
@test c2.comp_id.comp_name == :ch4forcing2

vars = Mimi.variable_names(c2)
@test length(vars) == 3

pars = Mimi.parameter_names(c2)
@test length(pars) == 6

end # module