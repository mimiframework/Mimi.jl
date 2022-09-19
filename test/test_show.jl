@testitem "Show" begin
    import Mimi:
        compdefs, compdef, ComponentId, MimiStruct, ParameterDef

    @defcomp X begin    
        x = Parameter(index = [time])
        y = Variable(index = [time])
        function run_timestep(p, v, d, t)
            v.y[t] = 1
        end
    end

    function test_show(obj, expected::AbstractString)
        buf = IOBuffer()
        show(buf, obj)
        @test String(take!(buf)) == expected
    end

    function showstr(obj)
        buf = IOBuffer()
        show(buf, obj)
        String(take!(buf))
    end

    compid = ComponentId(@__MODULE__, :something)
    test_show(compid, "ComponentId($(string(@__MODULE__)).something)")

    struct Foo <: MimiStruct
        a::Dict
        b::Int
        c::Float64
    end

    foo = Foo(Dict((:x=>10, :y=>20)), 4, 44.4)
    # Use typeof(Foo) so it works in test mode and using include(), which results in Main.TestShow.Foo.
    # test_show(foo, "$(typeof(foo))\n  a: Dict{Symbol,Int64}\n    y => 20\n    x => 10\n  b: 4\n  c: 44.4")

    # (:name, :datatype, :dim_names, :description, :unit, :default)
    # p = ParameterDef(:v1, Float64, [:time], "description string", "Mg C", 101)
    # test_show(p, "ParameterDef\n  name: :v1\n  datatype: Float64\n  dim_names: Symbol[:time]\n  description: \"description string\"\n  unit: \"Mg C\"\n  default: 101")

    # p = ParameterDef(:v1, Float64, [:time], "", "", nothing)
    # test_show(p, "ParameterDef\n  name: :v1\n  datatype: Float64\n  dim_names: Symbol[:time]\n  default: nothing")

    m = Model()
    set_dimension!(m, :time, 2000:2005)
    add_comp!(m, X)                         # Original component X
    update_param!(m, :X, :x, zeros(6))

    expected = """
    Model
        md: ModelDef(##anonymous#)
        comp_id: <ComponentId Mimi.##anonymous#>
        variables: OrderedCollections.OrderedDict{Symbol,VariableDef}
        parameters: OrderedCollections.OrderedDict{Symbol,ParameterDef}
        dim_dict: OrderedCollections.OrderedDict{Symbol,Union{Nothing, Dimension}}
            time => [2000, 2001, 2002, 2003, 2004, 2005]
        first: nothing
        last: nothing
        is_uniform: true
        comps_dict: OrderedCollections.OrderedDict{Symbol,AbstractComponentDef}
            X => ComponentDef(X)
            comp_id: <ComponentId TestShow.X>
            variables: OrderedCollections.OrderedDict{Symbol,VariableDef}
                y => VariableDef(y::Number)
                    1: time
            parameters: OrderedCollections.OrderedDict{Symbol,ParameterDef}
                x => ParameterDef(x::Number)
                    1: time
                default: nothing
            dim_dict: OrderedCollections.OrderedDict{Symbol,Union{Nothing, Dimension}}
                time => nothing
            first: nothing
            last: nothing
            is_uniform: true
            1: ExternalParameterConnection
            comp_name: :X
            param_name: :x
            model_param_name: :x
        model_params: Dict{Symbol,ModelParameter}
            x => ArrayModelParameter{TimestepArray{FixedTimestep{2000,1,2005},Float64,1}}
            values: TimestepArray{FixedTimestep{2000,1,2005},Float64,1}
                1: 0.0
                2: 0.0
                3: 0.0
                4: 0.0
                ...
                6: 0.0
                1: time
        number_type: Float64
        mi: nothing"""   # ignore (most) whitespace

    # Quote regex special characters
    # Modified from https://github.com/JuliaLang/julia/issues/6124
    function quotemeta(s::AbstractString) 
        res = replace(s, r"([()[\]{}?*\$.&~#=!<>|:])" => s"\\\1") 
        replace(res, "\0" => "\\0") 
    end

    re = quotemeta(expected)

    # remove the number in the gensym since it changes each run
    output = replace(showstr(m), r"(##anonymous#)\d+" => s"\1")

    @test_broken match(Regex(re), output) !== nothing

end
