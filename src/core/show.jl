#
# show() methods to make output of complex structures readable
#

# printstyled(IOContext(io, :color => true), "string", color=:red)

import Base: show

spaces = "  "

function _indent_level!(io::IO, delta::Int)
    level = get(io, :indent_level, 0)
    return IOContext(io, :indent_level => max(level + delta, 0))
end

indent(io::IO) = _indent_level!(io, 1)

"""
    printable(value)

Return a value that is not nothing.
"""
printable(value) = (value === nothing ? ":nothing:" : value)

function print_indented(io::IO, args...)
    level = get(io, :indent_level, 0)
    print(io, repeat(spaces, level), args...)
    nothing
end

function _show_field(io::IO, name::Symbol, value; show_empty=true)
    if !show_empty && isempty(value)
        return
    end

    print(io, "\n")
    print_indented(io, name, ": ")
    show(io, value)
end

function _show_field(io::IO, name::Symbol, dict::AbstractDict; show_empty=true)
    if !show_empty && isempty(dict)
        return
    end

    print(io, "\n")
    print_indented(io, name, ": ", typeof(dict))
    io = indent(io)
    for (k, v) in dict
        print(io, "\n")
        print_indented(io, k, " => ")
        show(io, v)
    end
    nothing
end

function _show_field(io::IO, name::Symbol, vec::Vector{T}; show_empty=true) where T
    print(io, "\n")
    print_indented(io, name, ": ", typeof(vec))

    count = length(vec)
    elide = false
    max_shown = 5
    if count > max_shown
        last = vec[end]
        vec = vec[1:max_shown-1]
        elide = true
    end

    for (i, value) in enumerate(vec)
        print(io, "\n")
        print_indented(io, "$i: ", value)
    end

    if elide
        print(io, "\n")
        print_indented(io, "...\n")
        print_indented(io, "$count: ")
        show(io, last)
    end
    nothing
end

function _show_field(io::IO, name::Symbol, vec::Vector{<: AbstractMimiType}; show_empty=true)
    if !show_empty && isempty(vec)
        return
    end

    print(io, "\n")
    print_indented(io, name, ": ")
    io = indent(io)
    for (i, value) in enumerate(vec)
        print(io, "\n")
        print_indented(io, "$i: ", value)
    end
end

function _show_fields(io::IO, obj, names; show_empty=true)
    for name in names
        value = getfield(obj, name)
        _show_field(io, name, value)
    end
    nothing
end

function _show_datum_def(io::IO, obj::AbstractDatumDef)
    print(io, typeof(obj), "($(obj.name)::$(obj.datatype))")
    io = indent(io)
    _show_field(io, :comp_path, obj.comp_path)
    _show_field(io, :dim_names, obj.dim_names)

    for field in (:description, :unit)
        _show_field(io, field, getfield(obj, field), show_empty=false)
    end
end

function show(io::IO, obj::ComponentId)
    print(io, "ComponentId($(obj.module_obj).$(obj.comp_name))")
    nothing
end

function show(io::IO, obj::ComponentPath)
    print(io, "ComponentPath$(obj.names)")
    nothing
end


function show(io::IO, obj::AbstractDimension)
    print(io, keys(obj))
    nothing
end

show(io::IO, obj::VariableDef) = _show_datum_def(io, obj)

function show(io::IO, obj::ParameterDef)
    _show_datum_def(io, obj)
    _show_field(indent(io), :default, obj.default)
end

function show(io::IO, obj::AbstractMimiType)
    print(io, typeof(obj))

    # If a name is present, print it as type(name)
    fields = fieldnames(typeof(obj))
    pos = findfirst(x -> x == :name, fields)

    if pos !== nothing
        print(io, "($(obj.name))")
        fields = deleteat!([fields...], pos)
    end

    _show_fields(indent(io), obj, fields)
end

function show(io::IO, obj::AbstractComponentDef)
    print(io, nameof(typeof(obj)), " id:", objectid(obj))

    fields = fieldnames(typeof(obj))

    # skip the 'namespace' field since it's redundant
    fields = [f for f in fields if f != :namespace]

    # Don't print parent or root since these create circular references
    for field in (:parent, :root)
        pos = findfirst(x -> x == field, fields)
        if pos !== nothing
            value = getfield(obj, field)
            name = printable(value === nothing ? nothing : nameof(value))
            fields = deleteat!([fields...], pos)
            print(io, "\n")
            print_indented(indent(io), "$field: $(typeof(value))($name)")
        end
    end

    io = indent(io)
    _show_fields(io, obj, fields)

    if obj isa AbstractComponentDef
        # print an abbreviated namespace
        print(io, "\n")
        print_indented(io, "namespace:")
        io = indent(io)
        for (name, item) in obj.namespace
            print(io, "\n")
            print_indented(io, name, ": ")
            show(io, typeof(item))
        end
    end
end

function show(io::IO, obj::VariableDefReference)
    print(io, "VariableDefReference(name=:$(obj.name) path=$(obj.comp_path))")
end

function show(io::IO, obj::ParameterDefReference)
    default = printable(obj.default)
    print(io, "ParameterDefReference(name=:$(obj.name) path=$(obj.comp_path) default=$default)")
end

function show(io::IO, obj::ModelInstance)
    # Don't print full type signature since it's shown in .variables and .parameters
    print(io, "ModelInstance")

    # Don't print the mi's ModelDef since it's redundant
    fields = fieldnames(typeof(obj))
    pos = findfirst(x -> x == :md, fields)
    fields = deleteat!([fields...], pos)

    io = indent(io)
    _show_fields(io, obj, fields)
    print(io, "\n")
    print_indented(io, "md: (not shown)")
end

#
# We might want to use a version of this to simplify. Imported forward from Mimi v0.9.1.
#
function _show(io::IO, obj::Model, which::Symbol)

    println(io, "Mimi.Model")
    md = obj.md
    mi = obj.mi

    println(io, "  Module: $(md.comp_id.module_obj)")

    println(io, "  Components:")
    for comp in values(components(md))
        println(io, "    $(comp.comp_id)")
    end

    if which == :full
        println(io, "  Dimensions:")
        for (k, v) in md.dim_dict
            println(io, "    $k => $v")
        end

        println(io, "  Internal Connections:")
        for conn in md.internal_param_conns
            println(io, "    $(conn)")
        end

        println(io, "  External Connections:")
        for conn in md.external_param_conns
            println(io, "    $(conn)")
        end

        println(io, "  Backups: $(md.backups)")
        println(io, "  Number type: $(md.number_type)")
    end
    println(io, "  Built: $(mi !== nothing)")
end

Base.show(io::IO, obj::Model) = _show(io, obj, :full)

Base.show(io::IO, ::MIME"text/plain", obj::Model) = _show(io, obj, :short)
