module TestDatumStorage

using Mimi
using Test

@defcomp foo begin
    v = Variable(index = [time])
    function run_timestep(p, v, d, ts)
        v.v[ts] = gettime(ts)
    end
end

@defcomp bar begin
    region = Index()
    v = Variable(index = [time, region])
    function run_timestep(p, v, d, ts)
        # v.v[ts, 1:end] = gettime(ts)
        for d in d.region
            v.v[ts, d] = gettime(ts)
        end
    end
end

years = 2001:2010
regions = [:A, :B]
comp_first = 2003
comp_last = 2008


#------------------------------------------------------------------------------
# 1. Single dimension case, fixed timesteps
#------------------------------------------------------------------------------

m = Model()
set_dimension!(m, :time, years)
add_comp!(m, foo, first=comp_first, last=comp_last)

run(m)
v = m[:foo, :v]
@test length(v) == length(years) # Test that the array allocated for variable v is the full length of the time dimension

# Test that the missing values were filled in before/after the first/last values
for (i, y) in enumerate(years)
    if y < comp_first || y > comp_last
        @test ismissing(v[i])
    else
        @test v[i] == y
    end
end

#------------------------------------------------------------------------------
# 2. Multi-dimension case, fixed timesteps
#------------------------------------------------------------------------------

m2 = Model()

set_dimension!(m2, :time, years)
set_dimension!(m2, :region, regions)
add_comp!(m2, bar, first=comp_first, last=comp_last)

run(m2)
v2 = m2[:bar, :v]
@test size(v2) == (length(years), length(regions)) # Test that the array allocated for variable v is the full length of the time dimension

# Test that the missing values were filled in before/after the first/last values
for (i, y) in enumerate(years)
    if y < comp_first || y > comp_last
        [@test ismissing(v2[i, j]) for j in 1:length(regions)]
    else
        [@test v2[i, j]==y for j in 1:length(regions)]
    end
end


end # module