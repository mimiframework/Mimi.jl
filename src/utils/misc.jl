"""
    interpolate(values, ts=10)

Linearly interpolate annual values from a vector of values
for timestep of length `ts`.
"""
function interpolate(values, ts=10)
    count = length(values)
    newvalues = zeros((count-1) * ts + 1)
    fracs = collect(range(0.0, 0.1, ts))

    for i = 1:count - 1
        start = values[i]
        stop  = values[i+1]
        diff  = stop - start

        start_idx = (i - 1) * ts + 1
        end_idx   = start_idx + ts - 1
        newvalues[start_idx:end_idx] = start + diff * fracs
    end

    newvalues[end] = values[end]
    return newvalues
end
