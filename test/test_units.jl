@testitem "Units" begin
    import Mimi: verify_units, connect_param!, ComponentReference

    # Try directly using verify_units
    @test verify_units("kg", "kg")
    @test !verify_units("kg", "MT")
    @test !verify_units("kg", "")

    # Create a model with some matching and some mis-matching units
    @defcomp Foo begin
        output = Variable(unit="kg")
    end

    @defcomp Bar begin
        input = Parameter(unit="MT")
    end

    @defcomp Baz begin
        input = Parameter(unit="kg")
    end

    m = Model()
    set_dimension!(m, :time, [1])
    foo = add_comp!(m, Foo)
    bar = add_comp!(m, Bar)
    baz = add_comp!(m, Baz)

    # Check that we cannot connect foo and bar...
    @test_throws ErrorException bar[:input] = foo[:output]
    #@test_throws ErrorException connect_param!(m, :Bar, :input,  :Foo, :output, ignoreunits=false)

    # ...unless we pass ignoreunits=true
    connect_param!(m, :Bar, :input,  :Foo, :output, ignoreunits=true)

    # But we can connect foo and baz
    baz[:input] = foo[:output]

end
