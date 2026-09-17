#
# Time-to-first-result benchmark.
#
# Mimi's dominant first-use cost is compilation, not work: for a large model the
# first `run` can take tens of seconds while the second takes about a second.
# That is what `src/precompile.jl` exists to reduce, and this script is how we
# check it has not regressed.
#
# Each measurement runs in a *fresh* Julia process, because the whole point is
# what a user pays on the first call in a new session. Run it as:
#
#     julia --project=. benchmark/latency.jl
#
# Timings are wall clock and machine-dependent; only before/after comparisons on
# the same machine, with everything precompiled, mean anything. Precompile first
# (`julia --project=. -e 'using Pkg; Pkg.precompile()'`), otherwise the first
# process measured pays for precompiling Mimi as well.
#

const PROJECT = Base.active_project()
const TUTORIAL = joinpath(@__DIR__, "..", "examples", "tutorial", "02-multi-region-model")

const WORKLOAD = """
    t0 = time(); using Mimi; t_using = time() - t0

    include(raw"$(joinpath(TUTORIAL, "multi-region-model.jl"))")
    using .MyModel

    t0 = time(); m = construct_MyModel(); t_construct = time() - t0
    t0 = time(); run(m); t_run = time() - t0

    # steady state: a model that is already built and run
    t_steady = minimum(begin t0 = time(); run(m); time() - t0 end for _ in 1:5)

    println("using=\$(t_using) construct=\$(t_construct) run=\$(t_run) steady=\$(t_steady)")
"""

function measure()
    out = read(`$(Base.julia_cmd()) --project=$PROJECT -e $WORKLOAD`, String)
    line = last(filter(!isempty, split(out, '\n')))
    return Dict(Symbol(k) => parse(Float64, v)
                for (k, v) in (split(f, '=') for f in split(strip(line))))
end

function main(nsamples::Int = 3)
    samples = [measure() for _ in 1:nsamples]
    best(k) = minimum(s[k] for s in samples)

    t_using, t_construct, t_run = best(:using), best(:construct), best(:run)

    println()
    println("  best of $nsamples fresh processes")
    println("  ---------------------------------")
    println("  using Mimi           ", round(t_using, digits = 3), " s")
    println("  first construct      ", round(t_construct, digits = 3), " s")
    println("  first run            ", round(t_run, digits = 3), " s")
    println("  time to first result ", round(t_using + t_construct + t_run, digits = 3), " s")
    println("  steady-state run     ", round(best(:steady), digits = 4), " s")
    println()
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end
