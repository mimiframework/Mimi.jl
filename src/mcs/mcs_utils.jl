# Use original distribution when resampling from SampleStore
_get_dist(rv::RandomVariable) = (rv.dist isa SampleStore ? rv.dist.dist : rv.dist)
