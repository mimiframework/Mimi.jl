using Mimi
include("/Users/lisarennels/.julia/dev/Mimi/wip/export_all.jl")

@defcomp A begin
    p1 = Parameter()
end

@defcomposite C begin
    foo = Component(A)
    rename_p1 = Parameter(foo.p1)
end

# ERROR: UndefVarError: foo not defined
# Stacktrace:
#  [1] top-level scope at /Users/lisarennels/.julia/dev/Mimi/src/core/defcomposite.jl:183
