#
# Various general-purpose functions for working with macros
#

# A general function to take a list of variable names with or without type
# constraints and return the name of an instantiated structure. To pass types,
# use args of the form :(name::type), e.g, [:(foo::Int64), :(bar::String)]
# TBD: move this to a "utilities" module.
function generate_struct(items; basename::Union{Symbol, String}="struct", parent::DataType=Any)
    name = gensym(basename)
    expr = :(struct $name <: $parent; end)

    # Add data elements to the struct expression
    args = expr.args[3].args
    append!(args, items)
    
    # Create the struct by eval'ing the expression
    eval(expr)

    # eval the symbol and return the new type
    return eval(name)
end