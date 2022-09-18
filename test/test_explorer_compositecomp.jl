@testitem "Explorer Composite Components" begin
    using DataFrames
    using VegaLite
    using Electron

    import Mimi: 
        dataframe_or_scalar, _spec_for_item, menu_item_list, getdataframe, dim_names, time_labels

    # Helper function returns true if VegaLite is verison 3 or above, and false otherwise
    function _is_VegaLite_v3()
        return isdefined(VegaLite, :vlplot) ? true : false
    end

    include("../examples/compositecomp-model.jl") # constructs and runs model
    # m's structure is as follows:
    #
    #          top
    #        /    \
    #       A       B
    #     /  \     /  \
    #    1    2   3    4


    # 1.  dataframe helper functions
    @test typeof(dataframe_or_scalar(m, :top, :fooA1)) == Float64 # same for fooA2, foo3, foo4
    @test typeof(dataframe_or_scalar(m, :top, :var_3_1)) == DataFrame
    @test typeof(dataframe_or_scalar(m, :top, :par_1_1)) == DataFrame

    #2.  Specs and menu
    items = [:fooA1, :fooA2, :foo3, :foo4, :var_3_1, :par_1_1]
    for item in items
        static_spec = _spec_for_item(m, :top, item; interactive = false)
        interactive_spec = _spec_for_item(m, :top, item)
        if length(dim_names(m, :top, item)) == 0
            name =  string(:top, " : ", item, " = ", m[:top, item])
        else
            name = string(:top, " : ", item)
        end
        @test static_spec["name"] == interactive_spec["name"] == name
    end

    s = menu_item_list(m)
    @test collect(keys(s)) == ["pars", "vars"]
    @test length(collect(keys(s["pars"]))) == 5
    @test length(collect(keys(s["vars"]))) == 1

    #3.  explore(m::Model)
    w = explore(m)
    @test typeof(w) == Electron.Window
    close(w)

    #4.  Mim.plot(m::Model, comp_name::Symbol, datum_name::Symbol; 
    #       dim_name::Union{Nothing, Symbol} = nothing)
    items = [:fooA1, :fooA2, :foo3, :foo4, :var_3_1, :par_1_1]
    for item in items
        p_type = _is_VegaLite_v3() ? VegaLite.VLSpec : VegaLite.VLSpec{:plot}
        @test typeof(Mimi.plot(m, :top, item)) == p_type
    end

    Mimi.close_explore_app()
end
