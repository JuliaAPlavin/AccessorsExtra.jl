# XXX: should upstream all of these – but cannot because FixArgs not in Base

InverseFunctions.inverse(f::FixArgsT(eachslice, (Placeholder,), (dims=Any,))) =
    @o stack(_, dims=f.kwargs.dims)
InverseFunctions.inverse(f::FixArgsT(stack, (Placeholder,), (dims=Any,))) =
    @o eachslice(_, dims=f.kwargs.dims)

stack_dropped(iter; dims, drop) = stack(iter; dims)

InverseFunctions.inverse(f::FixArgsT(eachslice, (Placeholder,), (dims=Any, drop=Any))) =
    @o stack_dropped(_, dims=f.kwargs.dims, drop=f.kwargs.drop)
InverseFunctions.inverse(f::FixArgsT(stack_dropped, (Placeholder,), (dims=Any, drop=Any))) =
    @o eachslice(_, dims=f.kwargs.dims, drop=f.kwargs.drop)

# XXX: piracy
# XXX: works for matrices, but not for vectors
# maybe overloading set() and not inverse() is better?
# eachrow and eachcol support both 1d and 2d, with vectors as columns
# but given their result, it's impossible to distinguish whether the input was a vector or a matrix
InverseFunctions.inverse(::typeof(eachrow)) = inverse(@o eachslice(_, dims=1, drop=true))
InverseFunctions.inverse(::typeof(eachcol)) = inverse(@o eachslice(_, dims=2, drop=true))
