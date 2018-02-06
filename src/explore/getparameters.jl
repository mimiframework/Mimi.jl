"""
parameters(m::Model, componentname::Symbol)

List all the parameters of `componentname` in model `m`.
"""

function parameters(m::Model, componentname::Symbol)
c = getmetainfo(m, componentname)
collect(keys(c.parameters))
end