using ExcelReaders
using Mimi: EmpiricalDistribution

function load_vector(path, range, header=false)
    tups = collect(load(path, range, header=header))
    name = fieldnames(tups[1])[1]   # field name of first item in NamedTuple
    map(obj -> getfield(obj, name), tups)
end

function load_empirical_dist(excel_file::AbstractString, 
                             values_range::AbstractString, 
                             probs_range::AbstractString="")                               
    values = load_vector(excel_file, values_range)
    probs = probs_range == "" ? nothing : load_vector(excel_file, probs_range)
    return EmpiricalDistribution(values, probs)
end
