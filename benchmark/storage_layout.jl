#
# Measure what Mimi's time-major storage layout costs a real model.
#
# Mimi allocates every TimestepArray in the dimension order the component author
# declared, and essentially every component declares `index=[time, region]`. Julia
# being column-major, that makes time the fastest-varying dimension: the values for
# a single year are strided across the whole array. Meanwhile the run loop
# (`_run_components`, src/core/instances.jl) iterates time on the outside and
# components on the inside, so each year sweeps the model's entire storage, pulling
# a 64-byte cache line per (array, cross-section element) to consume 8 bytes of it.
#
# `TimestepArray{T_TS, T, N, ti, S}` is parametric in its storage `S`, and all of
# `time_arrays.jl` indexes through `arr.data`. So we can hand a *transposed* storage
# array, re-wrapped in a `PermutedDimsArray` to restore the logical (time, region)
# shape, to a stock Mimi TimestepArray -- and the model's real, unmodified
# `run_timestep` functions will run against it. Nothing in Mimi's src/ is touched.
#
# Usage:
#   julia --project=<env with Mimi + MimiGIVE dev'd> benchmark/storage_layout.jl
#
# ---------------------------------------------------------------------------
# Results, Julia 1.13.0, single-threaded, i9-14900KS (48K L1d, 2M L2/P-core, 36M L3)
# ---------------------------------------------------------------------------
#
# All 151 GIVE variables (61 for CIAM) come out bit-identical under both layouts.
#
#   workload                            time-first   time-last   speedup
#   GIVE main model, minus Socioeconomic   34.5 ms     29.7 ms     1.18x
#     damage block only (16 components)    16.6 ms     13.3 ms     1.28x
#   CIAM slrcost (11,835 segments)        872.3 ms    863.7 ms     1.01x
#
# (`Socioeconomic` is excluded because under :SSP it is ~95% of the run and is
# dominated by a per-timestep DataFrame filter with a linear string search -- see
# MimiSSPs src/components/SSPs.jl:111. Under the production :RFF path that component
# has an essentially empty run_timestep, so the "minus Socioeconomic" row is the
# right proxy for a production main-model run rather than a caveat.)
#
# Footprint sweep, K interleaved replicas of GIVE's real damage block:
#
#   K=1   14.8 MiB   15.8 ms -> 12.4 ms   1.28x
#   K=2   29.5 MiB   34.2 ms -> 25.5 ms   1.34x
#   K=4   59.0 MiB   73.4 ms -> 54.0 ms   1.36x
#   K=8  118.0 MiB  160.5 ms -> 117.5 ms  1.37x
#
# The gain plateaus at ~1.37x well past any cache size, so GIVE is not simply
# "small enough to fit in L3" -- its component code has enough non-memory work
# (framework dispatch, `get_shifted_ts`, allocating `p.x[t,:]` slices) to hide most
# of the latency. A pure-memory kernel at the same shapes reaches ~7.4x, which is
# the ceiling the layout would be worth if that other overhead were removed.
#
# CIAM is unaffected despite a 433 MiB working set because its time dimension is
# only 29 long: the stride between consecutive segments is 232 bytes, which the
# hardware prefetcher absorbs. The penalty scales with `length(time)`, not with
# total footprint -- the main model's 551 timesteps give a 4408-byte stride.
#

using Mimi
using MimiGIVE
using Statistics: median

# ---------------------------------------------------------------------------
# Transposing a built ModelInstance
# ---------------------------------------------------------------------------

# Storage permutation that moves the time dimension (logical position `ti`) last.
_storage_perm(N, ti) = ((filter(!=(ti), 1:N))..., ti)

"""
    transpose_storage(arr, bufs)

Return a `TimestepArray` with the same type parameters, logical shape and time-range
view as `arr`, but backed by memory in which the time dimension varies slowest.
`bufs` is an `IdDict` of already-transposed backing buffers, so arrays that Mimi
shares between a source variable and the parameters connected to it keep sharing.
"""
function transpose_storage(arr::Mimi.TimestepArray{T_TS,T,N,ti,S}, bufs::IdDict) where {T_TS,T,N,ti,S}
    N == 1 && return arr   # a vector has no layout choice

    sperm = _storage_perm(N, ti)
    iperm = invperm(sperm)

    base = parent(arr.data)                  # parent(::Array) is the array itself
    raw = get!(bufs, base) do
        permutedims(base, sperm)
    end

    storage = if arr.data isa SubArray
        # `_get_view` (src/core/build.jl) slices the time dim for components with a
        # restricted first/last. Re-take that view in transposed coordinates.
        view(raw, arr.data.indices[collect(sperm)]...)
    else
        raw
    end

    return Mimi.TimestepArray{T_TS,T,N,ti}(PermutedDimsArray(storage, iperm))
end

transpose_storage(x, ::IdDict) = x   # scalars, plain Arrays, anything else: untouched

"""
    transpose_instance(ci)

Rebuild a `LeafComponentInstance` around transposed storage, leaving its `init` and
`run_timestep` functions -- the actual model code -- completely alone.
"""
function transpose_instance(ci::Mimi.LeafComponentInstance, bufs::IdDict, seen::IdDict)
    xf(x) = x isa Mimi.TimestepArray ? get!(() -> transpose_storage(x, bufs), seen, x) : x

    vars = Mimi.variables(ci)
    pars = Mimi.parameters(ci)
    vnt = Mimi.nt(vars)
    pnt = Mimi.nt(pars)

    vnt2 = NamedTuple{keys(vnt)}(map(xf, values(vnt)))
    pnt2 = NamedTuple{keys(pnt)}(map(xf, values(pnt)))

    V = Mimi.ComponentInstanceVariables(vnt2, Mimi.comp_paths(vars))
    P = Mimi.ComponentInstanceParameters(pnt2, Mimi.comp_paths(pars))

    new_ci = Mimi.LeafComponentInstance{typeof(V),typeof(P)}()
    new_ci.comp_name = ci.comp_name
    new_ci.comp_id = ci.comp_id
    new_ci.comp_path = ci.comp_path
    new_ci.first = ci.first
    new_ci.last = ci.last
    new_ci.variables = V
    new_ci.parameters = P
    new_ci.init = ci.init
    new_ci.run_timestep = ci.run_timestep
    return new_ci
end

"""
    leaf_instances(obj)

Flatten a built model instance into the leaf components, in the order the run loop
visits them.
"""
function leaf_instances(obj::Mimi.AbstractCompositeComponentInstance)
    out = Mimi.AbstractComponentInstance[]
    for ci in Mimi.components(obj)
        append!(out, leaf_instances(ci))
    end
    return out
end
leaf_instances(ci::Mimi.LeafComponentInstance) = [ci]

# ---------------------------------------------------------------------------
# Run loops -- deliberately the same shape as Mimi's own (instances.jl:398)
# ---------------------------------------------------------------------------

function run_all!(cis, dims, time_keys)
    clock = Mimi.Clock(time_keys)
    for ci in cis
        Mimi.init(ci, dims)
    end
    while !Mimi.finished(clock)
        for ci in cis
            Mimi.run_timestep(ci, clock, dims)
        end
        Mimi.advance(clock)
    end
    return nothing
end

# One component, all timesteps -- for the per-component breakdown.
function run_one!(ci, dims, time_keys)
    clock = Mimi.Clock(time_keys)
    while !Mimi.finished(clock)
        Mimi.run_timestep(ci, clock, dims)
        Mimi.advance(clock)
    end
    return nothing
end

function bench(f, reps)
    f()   # warm up / compile
    ts = [@elapsed f() for _ in 1:reps]
    return (min = minimum(ts), med = median(ts))
end

# ---------------------------------------------------------------------------
# Reporting helpers
# ---------------------------------------------------------------------------

fmt(x) = string(round(x * 1e3, digits = 2), " ms")

function footprint(cis)
    bufs = IdDict()
    for ci in cis, v in values(Mimi.nt(Mimi.variables(ci)))
        v isa Mimi.TimestepArray || continue
        ndims(v) == 1 && continue
        b = parent(v.data)
        bufs[b] = length(b) * (isconcretetype(eltype(b)) ? sizeof(eltype(b)) : 9)
    end
    for ci in cis, p in values(Mimi.nt(Mimi.parameters(ci)))
        p isa Mimi.TimestepArray || continue
        ndims(p) == 1 && continue
        b = parent(p.data)
        bufs[b] = length(b) * (isconcretetype(eltype(b)) ? sizeof(eltype(b)) : 9)
    end
    return (count = length(bufs), bytes = sum(values(bufs); init = 0))
end

"""
    compare_outputs(cis_a, cis_b)

Gate on correctness: the transposed model must reproduce the original bit for bit.
"""
function compare_outputs(cis_a, cis_b)
    bad = String[]
    checked = 0
    for (a, b) in zip(cis_a, cis_b)
        va, vb = Mimi.nt(Mimi.variables(a)), Mimi.nt(Mimi.variables(b))
        for k in keys(va)
            xa, xb = va[k], vb[k]
            xa isa Mimi.TimestepArray || continue
            checked += 1
            # Compare logical contents; `.data` has the same logical shape in both.
            isequal(collect(xa.data), collect(xb.data)) ||
                push!(bad, "$(a.comp_name).$(k)")
        end
    end
    return (checked = checked, bad = bad)
end

"""
    clone_instances(cis; transpose)

Copy a set of leaf instances onto fresh, independent storage (preserving the sharing
topology within the clone). Lets us put K copies of a real component block into one
time loop to sweep the working-set size.
"""
function clone_instances(cis; transpose::Bool)
    bufs = IdDict()
    seen = IdDict()
    function fresh(arr::Mimi.TimestepArray{T_TS,T,N,ti,S}) where {T_TS,T,N,ti,S}
        base = parent(arr.data)
        if transpose && N > 1
            sperm = _storage_perm(N, ti)
            iperm = invperm(sperm)
            raw = get!(() -> permutedims(base, sperm), bufs, base)
            st = arr.data isa SubArray ? view(raw, arr.data.indices[collect(sperm)]...) : raw
            return Mimi.TimestepArray{T_TS,T,N,ti}(PermutedDimsArray(st, iperm))
        else
            raw = get!(() -> copy(base), bufs, base)
            st = arr.data isa SubArray ? view(raw, arr.data.indices...) : raw
            return Mimi.TimestepArray{T_TS,T,N,ti}(st)
        end
    end
    xf(x) = x isa Mimi.TimestepArray ? get!(() -> fresh(x), seen, x) : x

    out = Mimi.AbstractComponentInstance[]
    for ci in cis
        vnt = Mimi.nt(Mimi.variables(ci))
        pnt = Mimi.nt(Mimi.parameters(ci))
        V = Mimi.ComponentInstanceVariables(NamedTuple{keys(vnt)}(map(xf, values(vnt))),
                                            Mimi.comp_paths(Mimi.variables(ci)))
        P = Mimi.ComponentInstanceParameters(NamedTuple{keys(pnt)}(map(xf, values(pnt))),
                                             Mimi.comp_paths(Mimi.parameters(ci)))
        n = Mimi.LeafComponentInstance{typeof(V),typeof(P)}()
        n.comp_name = ci.comp_name
        n.comp_id = ci.comp_id
        n.comp_path = ci.comp_path
        n.first = ci.first
        n.last = ci.last
        n.variables = V
        n.parameters = P
        n.init = ci.init
        n.run_timestep = ci.run_timestep
        push!(out, n)
    end
    return out
end

# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

# Interleave the two arms so clock drift and thermal effects hit both equally --
# measured naively, the same workload varies by more than the effect being measured.
function ab(fa, fb; reps = 40)
    fa(); fb(); GC.gc()
    ta = Float64[]; tb = Float64[]
    for _ in 1:reps
        push!(ta, @elapsed fa())
        push!(tb, @elapsed fb())
    end
    return (a = ta, b = tb)
end

function report(label, r)
    println(rpad(label, 40),
            lpad(fmt(minimum(r.a)), 12), lpad(fmt(minimum(r.b)), 12),
            lpad(string(round(minimum(r.a) / minimum(r.b), digits = 2), "x"), 9),
            lpad(string(round(median(r.a) / median(r.b), digits = 2), "x"), 9))
end

function main(; socioeconomics_source = :SSP, SSP_scenario = "SSP245")
    m = MimiGIVE.get_model(; socioeconomics_source, SSP_scenario)
    Mimi.build!(m)
    mi = Mimi.modelinstance(m)

    cis = leaf_instances(mi)
    time_keys = Mimi.dim_keys(m.md, :time)
    dims = Mimi._dim_value_named_tuple(mi, Mimi.Clock(time_keys))

    bufs = IdDict(); seen = IdDict()
    cis_t = [transpose_instance(ci, bufs, seen) for ci in cis]

    run_all!(cis, dims, time_keys)
    run_all!(cis_t, dims, time_keys)
    chk = compare_outputs(cis, cis_t)
    isempty(chk.bad) ||
        error("transposed model disagrees on $(length(chk.bad)) variables: $(first(chk.bad, 10))")
    println("correctness: $(chk.checked) variables bit-identical across both layouts\n")

    # The Socioeconomic component is excluded from the second row: under :SSP it is
    # ~95% of the run and is dominated by a linear string search, which has nothing
    # to do with storage layout and swamps everything else.
    keep   = [c for c in cis   if c.comp_name != :Socioeconomic]
    keep_t = [c for c in cis_t if c.comp_name != :Socioeconomic]
    dmg    = [c for c in keep   if c.first !== nothing && c.first >= 2020]
    dmg_t  = [c for c in keep_t if c.first !== nothing && c.first >= 2020]

    println(rpad("workload", 40), lpad("time-first", 12), lpad("time-last", 12),
            lpad("min", 9), lpad("median", 9))
    report("GIVE main model, all components", ab(() -> run_all!(cis, dims, time_keys),
                                                 () -> run_all!(cis_t, dims, time_keys); reps = 12))
    report("  minus Socioeconomic", ab(() -> run_all!(keep, dims, time_keys),
                                       () -> run_all!(keep_t, dims, time_keys)))
    report("  damage block only", ab(() -> run_all!(dmg, dims, time_keys),
                                     () -> run_all!(dmg_t, dims, time_keys)))

    # CIAM: the largest cross-section in the GIVE stack (11,835 segments), but only
    # 29 timesteps -- so the stride between consecutive segments is just 232 bytes.
    mc, _ = MimiGIVE.get_ciam(m)
    Mimi.build!(mc)
    mic = Mimi.modelinstance(mc)
    cis_c = leaf_instances(mic)
    tk_c = Mimi.dim_keys(mc.md, :time)
    dims_c = Mimi._dim_value_named_tuple(mic, Mimi.Clock(tk_c))
    bc = IdDict(); sc = IdDict()
    cis_ct = [transpose_instance(c, bc, sc) for c in cis_c]
    run_all!(cis_c, dims_c, tk_c); run_all!(cis_ct, dims_c, tk_c)
    chk_c = compare_outputs(cis_c, cis_ct)
    isempty(chk_c.bad) || error("CIAM mismatch: $(first(chk_c.bad, 10))")
    report("CIAM slrcost (11835 segments)", ab(() -> run_all!(cis_c, dims_c, tk_c),
                                               () -> run_all!(cis_ct, dims_c, tk_c); reps = 7))

    # Working-set sweep on GIVE's real damage components, to separate "the model is
    # small enough to fit in cache" from "the code is not memory-bound".
    println("\nFootprint sweep (K interleaved replicas of the damage block):")
    println(rpad("K", 4), lpad("footprint", 12), lpad("time-first", 12),
            lpad("time-last", 12), lpad("speedup", 10))
    for K in (1, 2, 4, 8)
        A = reduce(vcat, [clone_instances(dmg; transpose = false) for _ in 1:K])
        B = reduce(vcat, [clone_instances(dmg; transpose = true) for _ in 1:K])
        r = ab(() -> run_all!(A, dims, time_keys), () -> run_all!(B, dims, time_keys);
               reps = K <= 2 ? 25 : 10)
        println(rpad(K, 4),
                lpad(string(round(footprint(A).bytes / 2^20, digits = 1), " MiB"), 12),
                lpad(fmt(minimum(r.a)), 12), lpad(fmt(minimum(r.b)), 12),
                lpad(string(round(minimum(r.a) / minimum(r.b), digits = 2), "x"), 10))
        A = B = nothing
        GC.gc()
    end
    return nothing
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end
