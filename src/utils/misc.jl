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

"""
    read_params(f, range::String, count::Int, sheet::String="Base")

Get parameters from DICE2010 excel sheet.

`range` is a single cell or a range of cells in the excel sheet.
  Must be a cell reference of the form "A27" or a range "B56:B77".

`count` is the length of the time dimension; ignored if range 
   refers to a single cell.

`sheet` is the name of the worksheet in the Excel file to read from.
  Defaults to "Base".

Examples:   
    values = read_params(f, "B15:BI15", 40)   # read only the first 40 values

    value = read_params(f, "A27", sheet="Parameters")
    value = read_params(f, "A27:A27", sheet="Parameters") # same as above
"""
function read_params(f, range::String, T::Int=60; sheet::String="Base")
    data = readxl(f, "$sheet\!$range")
    parts = split(range, ":")
    return (length(parts) == 1 || parts[1] == parts[2]) ? data : Vector{Float64}(data[1:T])
end
