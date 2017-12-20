# Mimi.jl v0.3.1 Release Notes
* Make julia 0.6.x compatible
* Drop julia 0.5 support

# Mimi.jl v0.3.0 Release Notes
* Drop julia 0.4 support
* Add plotting functionality
* New internal data structure representation of a model
* Running a model automatically invokes building a ModelInstance first
* Add `delete!` function for removing a component from a model
* Add functions to retrieve the index of a model, parameter, or variable
* Add ability to test local dependent Mimi models in test_dependencies.jl
* Support for NamedArrays for parameters
* Checks for the validity of input arguments for all exported Mimi functions
* Rearrange src file structure; create mimi-core.jl
* Remove setbestguess and setrandom functions

# Mimi.jl v0.2.3 Release Notes
* Fix an error in the documentation

# Mimi.jl v0.2.2 Release Notes
* Fix a bug in setleftoverparameters

# Mimi.jl v0.2.1 Release Notes
* Fix a bug in the dependency testing code

# Mimi.jl v0.2.0 Release Notes
* External parameters get automatically converted to the correct number type
* julia 0.5 compatible

# Mimi.jl v0.1.1 Release Notes
* Documentation updates
* Add Lint.jl support
* Various bug fixes

# Mimi.jl v0.1.0 Release Notes
* Move type generation from macro to runtime phase (low level dev feature)
* Rename the timestep function to run_timestep
* Move documentation to use Documenter.jl

# Mimi.jl v0.0.3 Release Notes
* Drop julia 0.3 support
* Use a parametric type for number fields (low level dev feature)

# Mimi.jl v0.0.2 Release Notes
* Make julia 0.4 compatible

# Mimi.jl v0.0.1 Release Notes
* Initial tagged version
