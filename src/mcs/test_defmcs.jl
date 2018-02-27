using Mimi
using Distributions

mcs = @defmcs begin
    # Define random variables. The rv() is required to disambiguate an
    # RV definition name = Dist(args...) from application of a distribution
    # to an external parameter. This makes the (less common) naming of an
    # RV slightly more burdensome, but it's only required when defining
    # correlations or sharing an RV across parameters.
    rv(name1) = Normal(10, 3)
    rv(name2) = Uniform(0.75, 1.25)
    rv(name3) = LogNormal(20, 4)

    # define correlations
    name1:name2 = 0.7
    name1:name3 = 0.5

    # assign RVs to model Parameters
    ext_var1[2010:2049, (US, CHI)] = name3
    ext_var2[2050, US] += name1
    ext_var2[2050, US] += name1
    ext_var3 *= name2
    ext_var4 += Normal(0, 1)
    ext_var5[2010:2050, :] *= name2
    ext_var6[2010:2100, :] *= Uniform(0.8, 1.2)

    # indicate which parameters to save for each model run. Specify
    # a parameter name or some slice of its data, similar to the
    # assignment of RVs, above.
    save(param1, param2, param3[2010:2100], param4[:, (US, CHI)])
end
