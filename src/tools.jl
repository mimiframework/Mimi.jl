# Begin plotting section
using Plots

"""
Extends the Plots module to be able to take a model information parameters for
convenience. More advanced plotting may require accessing the Plots module directly.
"""
function Plots.plot(m::Model, component::Symbol, parameter::Symbol ; index::Symbol = :time, legend::Symbol = nothing, x_label = string(index), y_label = string(parameter))
  if isnull(m.mi)
    error("A model must be run before it can be plotted")
  end

  # Create axis labels
  try
    units = getmetainfo(m, component).parameters[parameter].unit
    units = string(" [", units, "]")
  catch
    units = ""
  end

  # Convert labels from camel case/snake case
  if x_label == string(index)
    x_label = prettifystring(x_label)
  end

  if y_label == string(parameter)
    y_label = prettifystring(y_label)
  end

  x_label = string(x_label, units)
  y_label = string(y_label, units)

  plt = plot() # Clear out any previous plots

  if is(legend, nothing)
    # Assume that we are only plotting one line (i.e. it's not split up by regions)
    plot(plt, m.indices_values[index], m[component, parameter], xlabel=x_label, ylabel=y_label)
  else
    # For multiple lines, we need to read the legend labels from legend
    for line_index in 1:size(m[component, parameter])[2] # TODO: Check that these dimensions match
      plot!(plt, m.indices_values[index], m[component, parameter][:,line_index], label = m.indices_values[legend][line_index], xlabel=x_label, ylabel=y_label)
    end
  end

  return plt
end

"""
Accepts a camelcase or snakecase string, and makes it human-readable
e.g. camelCase -> Camel Case; snake_case -> Snake Case
Warning: due to limitations in Julia's implementation of regex (or limits in my
understanding of Julia's implementation of regex), cannot handle camelcase strings
with more than 2 consecutive capitals, e.g. fileInTXTFormat -> File In T X T Format
"""
function prettifystring(s::String)
  if contains(s, "_")
    # Snake Case
    s = replace(s, r"_", s" ")
  else
    # Camel Case
    s = replace(s, r"([a-z])([A-Z])", s"\1 \2")
    s = replace(s, r"([A-Z])([A-Z])", s"\1 \2")
  end

  # Capitalize the first letter of each word
  s_arr = split(s)
  to_ret = ""
  for word in s_arr
    word_caps = string(uppercase(word[1]), word[2:length(word)])
    to_ret = string(to_ret, word_caps, " ")
  end

  # Return our string, minus the trailing space that was added
  return to_ret[1:length(to_ret) - 1]
end

# End plotting section
