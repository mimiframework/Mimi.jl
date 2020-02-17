#module TestCompositeSimple

using Test
using Mimi

import Mimi:
    ComponentId, ComponentPath, DatumReference, ComponentDef, AbstractComponentDef,
    CompositeComponentDef, ModelDef, build, time_labels, compdef, find_comp,
    import_params!

@defcomp Leaf begin
    p1 = Parameter()
    v1 = Variable()

    function run_timestep(p, v, d, t)
        v.v1 = p.p1
    end
end

@defcomposite Intermediate begin
    Component(Leaf)
    v1 = Variable(Leaf.v1)
end

@defcomposite Top begin
    Component(Intermediate)
    v = Variable(Intermediate.v1)
    p = Parameter(Intermediate.p1)
    connect(Intermediate.p1, Intermediate.v1)
end


m = Model()
md = m.md
set_dimension!(m, :time, 2005:2020)

add_comp!(m, Top)

top = md[:Top]
inter = top[:Intermediate]
leaf = inter[:Leaf]

# Can do this, referencing :p in Top,
#set_param!(m, :Top, :p, 10)

# Or, import into model and reference it there
import_params!(m)
set_param!(m, :p, 10)

build(m)
run(m)
#end
