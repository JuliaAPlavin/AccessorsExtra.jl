struct Placeholder end

Base.show(io::IO, ::Placeholder) = print(io, "_")
Base.show(io::IO, ::MIME"text/plain", ::Placeholder) = print(io, "_")

struct FixArgs{F, T<:Tuple, NT<:NamedTuple}
    f::F
    args::T
    kwargs::NT
end

function fixargs(f, args...; kwargs...)
    # XXX: sometimes these checks take significant time?..
    # @assert hasplaceholder(args)
    # @assert !hasplaceholder(values(values(kwargs)))
    @assert Placeholder() ∈ args
    @assert Placeholder() ∉ values(kwargs)
    FixArgs(f, args, values(kwargs))
end
# @inline hasplaceholder(xs::T) where {T<:Tuple} = (Placeholder() ∈ xs)::Bool
# @generated hasplaceholder(xs::T) where {T<:Tuple} = Placeholder ∈ T.parameters

@inline function (fa::FixArgs)(arg)
    args = map(x -> x isa Placeholder ? arg : x, fa.args)
    fa.f(args...; fa.kwargs...)
end

FixArgsT(f::Function, args::Tuple) = FixArgsT(f, args, (;))
FixArgsT(f::Function, args::Tuple, kwargs::NamedTuple) = FixArgsT(f, Tuple{args...}, NamedTuple{keys(kwargs), <:Tuple{kwargs...}})
FixArgsT(f::Function, args::Type, kwargs::NamedTuple) = FixArgsT(f, args, NamedTuple{keys(kwargs), <:Tuple{kwargs...}})
FixArgsT(f::Function, args::Tuple, kwargs::Type) = FixArgsT(f, Tuple{args...}, kwargs)
function FixArgsT(f::Function, args::Type{A}, kwargs::Type{KW}) where {A<:Tuple,KW<:NamedTuple}
    @assert Base.issingletontype(typeof(f))
    FixArgs{typeof(f), <:A, <:KW}
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


for kws in [(:rev,), (:by,), (:rev, :by), (:by, :rev)]
    @eval set(obj, o::FixArgsT(sort, (Placeholder,), NamedTuple{$kws}), val) = @set obj[sortperm(obj; o.kwargs...)] = val
    @eval modify(f, obj, o::FixArgsT(sort, (Placeholder,), NamedTuple{$kws})) = @modify(f, obj[sortperm(obj; o.kwargs...)])
end
