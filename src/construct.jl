function construct end

construct(::Type{T}, (_,x)::Pair{PropertyLens{:re}}, (_,y)::Pair{PropertyLens{:im}}) where {T<:Complex} = T(x, y)

function construct(::Type{T}, (_,x)::Pair{typeof(abs)}, (_,y)::Pair{typeof(angle)}) where {T<:Complex}
    @assert x >= zero(x)
    convert(T, cis(y) * x)
end

construct(::Type{T}, (_,x)::Pair{typeof(only)}) where {T<:Union{Tuple,Set}} = T((x,))
construct(::Type{T}, (_,x)::Pair{typeof(only)}) where {T<:Vector} = convert(T, [x])
construct(::Type{NamedTuple{KS}}, (_,x)::Pair{typeof(only)}) where {KS} = NamedTuple{KS}((x,))

construct(::Type{NamedTuple}, args::Vararg{Pair{<:PropertyLens}}) =
    foldl(args; init=(;)) do acc, a
        insert(acc, first(a), last(a))
    end

construct(T::Type{Tuple{}})::T = T()
construct(T::Type{<:Tuple{Any}}, (_, x)::Pair{typeof(only)})::T = T(x)
construct(T::Type{<:Tuple{Any}}, (_, x)::Pair{typeof(first)})::T = T(x)
construct(T::Type{<:Tuple{Any}}, (_, x)::Pair{typeof(last)})::T = T(x)
construct(T::Type{<:Tuple{Any,Any}}, (_, x)::Pair{typeof(first)}, (_, y)::Pair{typeof(last)})::T = constructorof(T)(x, y)
construct(T::Type{<:Tuple{Any,Any}}, (_, n)::Pair{typeof(norm)}, (_, a)::Pair{typeof(splat(atan))})::T = constructorof(T)((n .* sincos(a))...)


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
