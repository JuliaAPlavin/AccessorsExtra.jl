struct Placeholder end

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


struct PropertyFunction{props, F}
    func::F
end
PropertyFunction{props}(func) where {props} = PropertyFunction{props, typeof(func)}(func)

(pf::PropertyFunction{props})(obj) where {props} = pf.func(obj)

needed_properties(::Type{<:PropertyFunction{props}}) where {props} = props

needed_properties(::ComposedFunction{O,I}) where {I,O} = needed_properties(I)
needed_properties(::Type{PropertyLens{P}}) where {P} = (P,)

needed_properties(::F) where {F} = needed_properties(F)
needed_properties(::Type{F}) where {F} = error("Cannot determine needed properties for function $F")
