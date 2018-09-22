module TestComponents

using Mimi
using Test

import Mimi:
    reset_compdefs, compdefs, compdef, compkeys, hascomp, _compdefs, first_period, 
    last_period, compmodule, compname, numcomponents, dump_components, 
    dimensions

reset_compdefs()

@test length(_compdefs) == 3 # adder, ConnectorCompVector, ConnectorCompMatrix

my_model = Model()

# Try running model with no components
@test length(compdefs(my_model)) == 0
@test numcomponents(my_model) == 0
@test_throws ErrorException run(my_model)

# Now add several components to the module
@defcomp testcomp1 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp testcomp2 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

@defcomp testcomp3 begin
    var1 = Variable(index=[time])
    par1 = Parameter(index=[time])
    
    function run_timestep(p, v, d, t)
        v.var1[t] = p.par1[t]
    end
end

# Can't add component before setting time dimension
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Start building up the model
set_dimension!(my_model, :time, 2015:5:2110)
add_comp!(my_model, testcomp1)

# Testing that you cannot add two components of the same name
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Testing to catch adding component twice
@test_throws ErrorException add_comp!(my_model, testcomp1)

# Testing to catch if before or after does not exist
@test_throws ErrorException add_comp!(my_model, testcomp2, before=:testcomp3)

# N.B. Throws ArgumentError in v1.0, but ErrorException in 0.7!
@test_throws ArgumentError add_comp!(my_model, testcomp2, after=:testcomp3)

#Add more components to model
add_comp!(my_model, testcomp2)
add_comp!(my_model, testcomp3)

comps = compdefs(my_model)

#Test compdefs, compdef, compkeys, etc.
@test comps == compdefs(my_model.md)
@test length(comps) == 3
@test compdef(:testcomp3) == [comps...][3]
@test_throws ErrorException compdef(:testcomp4) #this component does not exist
@test [compkeys(my_model.md)...] == [:testcomp1, :testcomp2, :testcomp3]
@test hascomp(my_model.md, :testcomp1) == true && hascomp(my_model.md, :testcomp4) == false

def = compdef(:testcomp3)
@test first_period(def) == 2015
@test last_period(def) == 2110

@test compmodule(testcomp3) == :TestComponents
@test compname(testcomp3) == :testcomp3

@test numcomponents(my_model) == 3
add_comp!(my_model, testcomp3, :testcomp3_v2)
@test numcomponents(my_model) == 4

#Test some component dimensions fcns, other dimensions testing in test_dimensions
def_dims = dimensions(def)
@test eltype(def_dims) == Mimi.DimensionDef && length(def_dims) == 1
@test [def_dims...][1].name == :time

# dump_components() #view all components and their info

#Test reset_compdefs methods
reset_compdefs()
@test length(_compdefs) == 3 #adder, ConnectorCompVector, ConnectorCompMatrix
reset_compdefs(false)
@test length(_compdefs) == 0 

end #module
