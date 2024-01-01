InverseFunctions.inverse(f::FixArgs{typeof(eachslice), <:Tuple{Placeholder}, <:NamedTuple{(:dims,)}}) =
    @o stack(_, dims=f.kwargs.dims)
InverseFunctions.inverse(f::FixArgs{typeof(stack), <:Tuple{Placeholder}, <:NamedTuple{(:dims,)}}) =
    @o eachslice(_, dims=f.kwargs.dims)

stack_dropped(iter; dims, drop) = stack(iter; dims)

InverseFunctions.inverse(f::FixArgs{typeof(eachslice), <:Tuple{Placeholder}, <:NamedTuple{(:dims, :drop)}}) =
    @o stack_dropped(_, dims=f.kwargs.dims, drop=f.kwargs.drop)
InverseFunctions.inverse(f::FixArgs{typeof(stack_dropped), <:Tuple{Placeholder}, <:NamedTuple{(:dims, :drop)}}) =
    @o eachslice(_, dims=f.kwargs.dims, drop=f.kwargs.drop)
