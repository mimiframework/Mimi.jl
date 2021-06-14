using Mimi

# Define a simple component
# =========================

@defcomp component1 begin

    # First define the state this component will hold
    savingsrate = Parameter(default = 1.0)

    # Second, define the (optional) init function for the component
    function init(p, v, d)
    end

    # Third, define the run_timestep function for the component
    function run_timestep(p, v, d, t)
    end

end

# Create a model uses the component
# =================================

m = Model()
add_comp!(m, component1)

# Run model
# =========

run(m)

# Explore the model variables and parameters with the explorer UI
# =================================

explore(m)

# Access the variables in the model
# =================================
