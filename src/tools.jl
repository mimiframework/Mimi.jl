# Begin plotting section
using Plots

"""
Three defaults: single line plot, multiple line plots with legend, bar graph
when indexing over regions, etc.
"""
function Plots.plot(m::Model, component::Symbol, parameter::Symbol ; index::Symbol = :time, legend::Symbol = nothing, xlabel = string(index), ylabel = string(parameter))
  if isnull(m.mi)
    error("A model must be run before it can be plotted")
  end

  plt = plot() # Clear out any previous plots

  if is(legend, nothing)
    # Assume that we are only plotting one line (i.e. it's not split up by regions)
    plot(plt, m.indices_values[index], m[component, parameter])
  else
    # For multiple lines, we need to read the legend labels from legend
    for line_index in 1:size(m[component, parameter])[2] # TODO: Check that these dimensions match
      plot!(plt, m.indices_values[index], m[component, parameter][:,line_index], label = m.indices_values[legend][line_index])
    end
  end

  # Add axis labels
  try
    units = getmetainfo(m, component).parameters[parameter].unit
    units = string("[", units, "]")
  catch
    units = ""
  end

  # Convert labels from camel case/snake case
  if xlabel == string(index)
    xlabel = prettifyStringForLabels(xlabels)
  end

  if ylabel == string(parameter)
    ylabel = prettifyStringForLabels(ylabel)
  end

  return plt
end

# Accepts a camel case or snake case string, and makes it human-readable
# e.g. camelCase -> Camel Case; snake_case -> Snake Case
# Warning: due to limitations in Julia's implementation of regex (or limits in my
# understanding of Julia's implementation of regex), cannot handle camel case strings
# with more than 2 consecutive capitals, e.g. thisIsTXTFormat -> This Is T X T Format
function prettifyStringForLabels(s::String)
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
