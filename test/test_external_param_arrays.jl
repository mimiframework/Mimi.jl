@testitem "ExternalParamArrays" begin
    using Mimi
    using Distributions
    import Mimi: model_params, model_param, get_model_param_name, OffsetTimeArray, compinstance
    import Mmap

    # Unwrap TimestepArray / SubArray layers to get at the array that actually owns
    # the memory, so we can compare identity with what the caller handed us.
    _root(x) = x
    _root(x::Mimi.TimestepArray) = _root(x.data)
    _root(x::SubArray) = _root(parent(x))
    _root(x::OffsetTimeArray) = _root(parent(x))

    @defcomp Passthrough begin
        r = Index()
        x = Parameter(index = [time, r])
        y = Variable(index = [time, r])

        function run_timestep(p, v, d, t)
            for i in d.r
                v.y[t, i] = p.x[t, i]
            end
        end
    end

    function _build_model(value; kwargs...)
        m = Model()
        set_dimension!(m, :time, 2000:2004)
        set_dimension!(m, :r, 1:3)
        add_comp!(m, Passthrough)
        update_param!(m, :Passthrough, :x, value; kwargs...)
        return m
    end

    #
    # By default the caller's array is copied, as it always has been
    #

    src = rand(5, 3)
    m = _build_model(src)
    run(m)

    @test m[:Passthrough, :y] == src
    @test _root(compinstance(m.mi, :Passthrough).parameters.x) !== src

    # so the caller may go on using their own array without disturbing the model
    original = copy(src)
    src[1, 1] = 42.0
    run(m)
    @test m[:Passthrough, :y] == original

    # the element type is no longer widened to Union{Missing, Float64} for a value
    # that cannot hold a missing, which is what removes the copy at set time
    x_sym = get_model_param_name(m.md, :Passthrough, :x)
    @test eltype(model_params(m.md)[x_sym].values.data) === Float64

    #
    # copy = false aliases the caller's array all the way to run_timestep
    #

    src2 = rand(5, 3)
    m2 = _build_model(src2; copy = false)
    run(m2)

    stored = model_params(m2.md)[get_model_param_name(m2.md, :Passthrough, :x)].values
    @test _root(stored) === src2
    @test _root(compinstance(m2.mi, :Passthrough).parameters.x) === src2
    @test m2[:Passthrough, :y] == src2

    #
    # The motivating case: memory-mapped, read-only file data
    #

    path = tempname()
    data = reshape(collect(1.0:15.0), 5, 3)
    open(io -> write(io, data), path, "w")

    mapped = open(path, "r") do io
        Mmap.mmap(io, Array{Float64,2}, (5, 3))
    end
    @test mapped isa Array{Float64,2}

    m3 = _build_model(mapped; copy = false)
    run(m3)
    @test _root(compinstance(m3.mi, :Passthrough).parameters.x) === mapped
    @test m3[:Passthrough, :y] == data

    mapped = nothing
    GC.gc()
    try; rm(path; force = true); catch; end   # Windows may still hold the mapping

    #
    # Mimi refuses to mutate a copy = false parameter on the caller's behalf
    #

    m4 = _build_model(rand(5, 3); copy = false)
    Mimi.build!(m4)
    x4_sym = get_model_param_name(m4.md, :Passthrough, :x)
    @test_throws ErrorException Mimi.update_param!(m4.mi, x4_sym, rand(5, 3))
    @test_throws ErrorException Mimi.update_param!(m4.mi, :Passthrough, :x, rand(5, 3))

    # ...including attaching a random variable to it
    sd_bad = @defsim begin
        Passthrough.x[2001, 1] *= Uniform(1.5, 2.5)
    end
    @test_throws ErrorException run(sd_bad, m4, 2)

    # the same simulation is fine against an ordinary (copied) parameter
    m5 = _build_model(rand(5, 3))
    sd_ok = @defsim begin
        Passthrough.x[2001, 1] *= Uniform(1.5, 2.5)
    end
    si = run(sd_ok, m5, 2)
    @test si.trials == 2

    # setting the parameter again without copy = false makes it mutable once more
    update_param!(m4, :Passthrough, :x, rand(5, 3))
    Mimi.build!(m4)
    Mimi.update_param!(m4.mi, get_model_param_name(m4.md, :Passthrough, :x), zeros(5, 3))
    @test all(iszero, m4.mi[:Passthrough, :x])

    #
    # Values that really can carry `missing` still get the widened element type
    #

    with_missings = Array{Union{Missing, Float64}}(undef, 5, 3)
    with_missings .= 1.0
    with_missings[1, 1] = missing

    m6 = _build_model(with_missings; copy = false)
    stored6 = model_params(m6.md)[get_model_param_name(m6.md, :Passthrough, :x)].values
    @test eltype(stored6.data) === Union{Missing, Float64}
    @test _root(stored6) === with_missings

    #
    # A parameter whose time span is narrower than the model's is presented through
    # a lazy OffsetTimeArray rather than materialized `missing` padding
    #

    m7 = Model()
    set_dimension!(m7, :time, 2000:2004)
    set_dimension!(m7, :r, 1:3)
    add_comp!(m7, Passthrough)
    short = rand(5, 3)
    update_param!(m7, :Passthrough, :x, short; copy = false)

    # widen the model's time dimension; the parameter's data now covers only part of it
    set_dimension!(m7, :time, 1998:2004)

    padded = model_params(m7.md)[get_model_param_name(m7.md, :Passthrough, :x)].values

    @test padded.data isa OffsetTimeArray
    @test size(padded.data) == (7, 3)
    @test parent(padded.data) === short              # the data itself was not copied
    @test all(ismissing, padded.data[1, :])          # reads outside the data give missing
    @test all(ismissing, padded.data[2, :])
    @test padded.data[3, :] == short[1, :]           # and inside it give the data
    @test padded.data[7, :] == short[5, :]

    # repeated redefinition must not nest wrappers
    set_dimension!(m7, :time, 1996:2004)
    padded2 = model_params(m7.md)[get_model_param_name(m7.md, :Passthrough, :x)].values
    @test padded2.data isa OffsetTimeArray
    @test parent(padded2.data) === short
    @test size(padded2.data) == (9, 3)
    @test padded2.data[5, :] == short[1, :]

    # a component read of a timestep with no data still raises a MissingException --
    # this is what @allow_missing, and therefore ConnectorComp, relies on
    @test_throws MissingException padded2[TimestepIndex(1), 1]

    #
    # Updating the model definition after a build must not disturb the built
    # instance, which is the isolation the build-time deepcopy provides
    #

    m8 = _build_model(collect(reshape(1.0:15.0, 5, 3)))
    run(m8)
    before = copy(m8[:Passthrough, :y])
    update_param!(m8, :Passthrough, :x, zeros(5, 3))
    @test m8.mi[:Passthrough, :y] == before    # built instance unchanged
    run(m8)                                    # rebuild picks the new values up
    @test all(iszero, m8[:Passthrough, :y])
end
