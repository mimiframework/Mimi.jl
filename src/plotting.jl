using Plots

function line_plot(m::Model component::Symbol, parameter::Symbol, index::Symbol = :time, legend::Symbol = nothing, xlabel = string(index), ylabel = string(parameter))
  if isnull(m.mi)
      run(m)
  end

  pyplot()
  plot(m.indices_values[index], m[component, parameter])
  

end
