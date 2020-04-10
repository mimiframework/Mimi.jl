using Mimi
include("/Users/lisarennels/.julia/dev/Mimi/wip/export_all.jl")

@defcomp A begin
    p1 = Parameter()
end

@defcomposite B begin
    Component(A) 
end

@defcomposite C begin
    foo = Component(A) 
    rename_p1 = Parameter(foo.p1) 
end

