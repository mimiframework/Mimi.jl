macro defcc(name, ex)
    legal_kw = (:bindings, :exports)

    @capture(ex, elements__)
    println(elements)
    for el in elements
        if ( @capture(el, component(args__; kwargs__)) || @capture(el, component(args__)) )
            if kwargs === nothing
                # extract kw args if expr didn't use a ";"
                kwargs = filter(arg ->  @capture(arg, lhs_ = rhs__), args)

                # remove the kw args, leaving non-kwargs
                filter!(arg -> !@capture(arg, lhs_ = rhs__), args)
            end
        end
        @info "args:$args kwargs:$kwargs"

        nargs = length(args)
        if !(nargs == 1 || nargs == 2)
            @error "defcc: component takes one or two non-keyword args, got: $args"
        end

        num_kwargs = length(kwargs)
        if num_kwargs > length(legal_kw)
            @error "defcc: component takes one or two non-keyword args, got: $args"
        end

        # initialize dict with empty vectors for each keyword, allowing keywords to
        # appear multiple times, with all values appended together.
        kwdict = Dict([kw => [] for kw in legal_kw])

        for kwarg in kwargs
            @info "kwarg: $kwarg"
            @capture(kwarg, lhs_ = rhs__)    # we've ensured these match
            if ! (lhs in legal_kw)
                @error "defcc: Unrecognized keyword $lhs"
            end

            append!(kwdict[lhs], rhs)
            for kw in keys(kwdict)
                val = kwdict[kw]
                @info "$kw: $val"
            end
        end

        id = args[1]
        name = (nargs == 2 ? args[2] : nothing)        

    end
end

@defcc foo begin
    component(foo, bar; bindings=[1], exports=[1, 2])
    component(foo2, bar2, exports=[1, 2])
    component(bar, other)
    # component(a, b, c)
end