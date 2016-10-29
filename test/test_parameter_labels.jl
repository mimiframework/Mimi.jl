using Mimi

@defcomp A begin
  varA = Variable(index=[time])
  parA = Parameter(index=[time])
end


m = model()
setindex(m, :time, collect(1:1:10))

addparameter(m, :parA, NamedArray(colect(1:10)))

addparameter()
