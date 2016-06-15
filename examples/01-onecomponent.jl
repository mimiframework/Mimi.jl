using Mimi

# Define a simple component
# =========================

# First define the state this component will hold

@defcomp component1 begin
    savingsrate = Parameter()

end

# Second, define the run_timestep function for the component

function run_timestep(s::component1, t::Int)
end

# Create a model uses the component
# =================================

m = Model()

addcomponent(m, component1)

# Run model
# =========

run(m)

# Access the variables in the model
# =================================
