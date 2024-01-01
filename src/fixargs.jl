struct Placeholder end

struct FixArgs{F, T<:Tuple, NT<:NamedTuple}
    f::F
    args::T
    kwargs::NT
end

function fixargs(f, args...; kwargs...)
    @assert Placeholder() ∈ args
    @assert Placeholder() ∉ values(kwargs)
    FixArgs(f, args, values(kwargs))
end

@inline function (fa::FixArgs)(arg)
    args = map(x -> x isa Placeholder ? arg : x, fa.args)
    fa.f(args...; fa.kwargs...)
end

Base.show(io::IO, fa::FixArgs) = Accessors.show_optic(io, fa)
Base.show(io::IO, ::MIME"text/plain", fa::FixArgs) = show(io, fa)

Accessors._shortstring(prev, fa::FixArgs) = "$(fa.f)($(_args_str(prev, fa.args))$(_args_str(prev, fa.kwargs)))"
_args_str(prev, args::Tuple) = @p let
    args
    map(_ isa Placeholder ? prev : _)
    join(__, ", ")
end
_args_str(prev, args::NamedTuple) = @p let
    args
    map(_ isa Placeholder ? prev : _)
    map("$_1=$_2", keys(__), values(__))
    join(__, ", ")
    isempty(__) ? __ : ", $__"
end
