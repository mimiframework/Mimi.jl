using Mimi
using Base.Test

import Mimi: 
    dataframe_or_scalar, getdataframe, createspec_singlevalue, 
    createspec_lineplot, createspec_multilineplot, createspec_barplot,
    getmultiline, getline, getbar, _spec_for_item, spec_list, explore, 
    getdataframe


# 1.  dataframe helper functions
# test dataframe_or_scalar
# test getdataframe

#2.  JSON strings for the spec "values" key
# test getmultiline
# test getline
# test getbar
# test getdatapart

#3.  full specs for VegaLite
# test createspec_singlevalue
# test createspec_multilineplot
# test createspec_lineplot
# test createspec_barplot

# test _spec_for_item
# test spec_list

#4.  explore
# test explore

# example from DataVoyager
# v = Voyager()
# @test typeof(v.w) == Electron.Window





