using Mimi
using Test

@test x_vec[begin] == time_dim_val[:,1,1][begin]
@test x_mat[begin,1] == time_dim_val[:,:,1][begin,1]
@test x_mat[begin,2] == time_dim_val[:,:,1][begin,2]
@test y_vec[begin] == time_dim_val[:,2,2][begin]
@test y_mat[begin,1] == time_dim_val[:,:,2][begin,1]
@test y_mat[begin,2] == time_dim_val[:,:,2][begin,2]
