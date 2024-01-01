function construct end

function construct(::Type{T}, x::Pair{PropertyLens{:re}}, y::Pair{PropertyLens{:im}}) where {T <: Complex}
    T(last(x), last(y))
end

function construct(::Type{T}, x::Pair{typeof(abs)}, y::Pair{typeof(angle)}) where {T <: Complex}
    @assert last(x) >= zero(last(x))
    convert(T, cis(last(y)) * last(x))
end

function construct(::Type{T}, x::Pair{typeof(only)}) where {T <: Union{Tuple,Set}}
    T((last(x),))
end

function construct(::Type{T}, x::Pair{typeof(only)}) where {T <: Vector}
    convert(T, [last(x)])
end

function construct(::Type{NamedTuple{KS}}, x::Pair{typeof(only)}) where {KS}
    NamedTuple{KS}((last(x),))
end

function construct(::Type{NamedTuple}, args::Vararg{Pair{<:PropertyLens}})
    foldl(args; init=(;)) do acc, a
        insert(acc, first(a), last(a))
    end
end


function construct(T, args::Vararg{Pair})
    pargs = @p args |> map(_process_invertible(_[1], _[2]))
    pargs == args && throw(MethodError(construct, Tuple{T, typeof.(args)...}))
    construct(T, pargs...)
end

_process_invertible(f, x) = f => x
function _process_invertible(f::ComposedFunction, x)
    fi, fo = _split_invertible(decompose(f))
    compose(fo...) => compose(fi...)(x)
end

_split_invertible(fs::Tuple{}) = ((), ())
function _split_invertible(fs::Tuple)
    first_inv = inverse(first(fs))
    if first_inv isa NoInverse
        ((), fs)
    else
        fi, fo = _split_invertible(Base.tail(fs))
        ((fi..., first_inv), fo)
    end
end


macro construct(exprs...)
    T, args... = exprs
    if length(args) == 1 && Base.isexpr(only(args), :block)
        args = filter(!MacroTools.isline, only(args).args)
    end
    ov_pairs = map(args) do arg
        @assert MacroTools.@capture arg (optic_ = value_)
        :($Accessors.@optic($optic) => $value)
    end
    return :(
        $construct($(T), $(ov_pairs...))
    ) |> esc
end
