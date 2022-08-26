# Mimi.jl v0.8.5 Release Notes
* Add keyword argument N to Sobol analyze function
* Update docs to no longer indicate Git requirement
* Change default for filename in generate_trials! function

# Mimi.jl v0.8.3 Release Notes
* Add error messages to modelegate
* Fix docstring bug
* Improve sensitivity analysis framework (change keyword args for run_sim)

# Mimi.jl v0.8.2 Release Notes
* Update dependency testing
* Fix bugs in variable dimensions functions

# Mimi.jl v0.8.1 Release Notes
* Update documentation to reflect use of Mimi Registry

# Mimi.jl v0.8.0 Release Notes
* Generalize mcs functionality to support other sensitivity analysis methods
* Update and augment documentation for sensitivity analysis

# Mimi.jl v0.7.0 Release Notes
* Drop julia 1.0 support
* Move to new github org (mimiframework)
* Add support for distributions that produce a matrix of values on each draw,
* Change internals to support precompilation for components as packages
    - Eliminated global dict of component defs
    - Fixed uses of eval

# Mimi.jl v0.6.4 Release Notes
* Documentation updates
* Tutorials bug and consistency updates
* Update the way to add models to mcs
* Add methods and docstrings for dimension-related functions
* Add interactive slider bar to explorer line plots
* Simplify saving single explorer plots
* Add references to forum and remove references to gitter chatroom
* Pass correct line numbers to macros to improve error reporting

# Mimi.jl v0.6.3 Release Notes
* Add tutorials to documentation

# Mimi.jl v0.6.2 Release Notes
* Fix interaction of explorer with missing data

# Mimi.jl v0.6.1 Release Notes
* Add anonymous dimensions back in
* Allow for backup data with missing values
* Documentation updates

# Mimi.jl v0.6.0 Release Notes
* Drop julia 0.6 support, add julia 1.0 support

# Mimi.jl v0.5.1 Release Notes
* Disable topological ordering, remove offset keyword

# Mimi.jl v0.5.0 Release Notes
* Major redesign with lots of breaking changes

# Mimi.jl v0.4.0 Release Notes
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
