function construct end

function construct(::Type{T}, (_,x)::Pair{typeof(abs)}, (_,y)::Pair{typeof(angle)}) where {T<:Complex}
    @assert x >= zero(x)
    convert(T, cis(y) * x)
end

construct(T::Type{<:Set}, (_,x)::Pair{typeof(only)}) = T((x,))
construct(T::Type{<:Tuple}, (_,x)::Pair{typeof(only)}) = T((x,))
for OF in (only, first, last)
    @eval construct(::Type{T}, (_,x)::Pair{typeof($OF)}) where {T<:Vector} = convert(T, [x])
    @eval construct(T::Type{<:NamedTuple{KS}}, (_,x)::Pair{typeof($OF)}) where {KS} = (@assert length(KS) == 1; T((x,)))
    @eval construct(T::Type{<:Tuple{Any}}, (_, x)::Pair{typeof($OF)})::T = T(x)
end

construct(T::Type{Tuple{}})::T = T()
function construct(T::Type{<:Tuple}, args::Vararg{Pair{<:IndexLens}})::T
    @assert map(a -> only(first(a).indices), args) === ntuple(identity, length(args))
    constructorof(T)(last.(args)...)
end
construct(T::Type{<:Tuple{Any,Any}}, (_, x)::Pair{typeof(first)}, (_, y)::Pair{typeof(last)})::T = constructorof(T)(x, y)
construct(T::Type{<:Tuple{Any,Any}}, (_, n)::Pair{typeof(splat(hypot))}, (_, a)::Pair{typeof(splat(atan))})::T = constructorof(T)((n .* sincos(a))...)

construct(::Type{NamedTuple}, args::Vararg{Pair}) =
    foldl(args, init=(;)) do acc, (o, x)
        insert⁺(acc, o, x)
    end
# disambiguation:
construct(::Type{NamedTuple}, args::Vararg{Pair{<:PropertyLens}}) =
    foldl(args; init=(;)) do acc, a
        insert(acc, first(a), last(a))
    end

# insert⁺ is a neat piece of functionality by itself!
struct InsertShouldJustInverse end

insert⁺(obj, optic, val) = insert(obj, optic, val)
insert⁺(obj, os::ConcatOptics, val) = _foldl(os.optics; init=obj) do obj, o
    insert⁺(obj, o, val)
end
insert⁺(obj::InsertShouldJustInverse, optic, val) = inverse(optic)(val)
insert⁺(obj, optic::ComposedFunction, val) =
    if hasoptic(obj, optic.inner)
        modify(obj, optic.inner) do inner_obj
            insert⁺(inner_obj, optic.outer, val)
        end
    else
        insert⁺(obj, optic.inner, insert⁺(default_empty_obj(optic.outer), optic.outer, val))
    end

default_empty_obj(::IndexLens{<:Tuple{<:Integer}}) = ()
default_empty_obj(::PropertyLens) = (;)
default_empty_obj(f::ComposedFunction) = default_empty_obj(f.inner)
default_empty_obj(f) = inverse(f) isa NoInverse ? throw(MethodError(default_empty_obj, f)) : InsertShouldJustInverse()


_propname(::PropertyLens{P}) where {P} = P
construct(::Type{T}, arg1::Pair{<:PropertyLens}, args::Vararg{Pair{<:PropertyLens}}) where {T} = _construct(T, arg1, args...)
function _construct(::Type{T}, args::Vararg{Pair{<:PropertyLens}})::T where {T}
    @assert fieldnames(T) == map(_propname ∘ first, args)
    constructorof(T)(map(last, args)...)
end


construct(::Type{Any}, args::Vararg{Pair}) = 
    foldl(args, init=default_empty_obj(first(first(args)))) do acc, (o, x)
        insert⁺(acc, o, x)
    end
construct(::Type{Any}, args::Vararg{Pair{<:PropertyLens}}) = 
    foldl(args, init=default_empty_obj(first(first(args)))) do acc, (o, x)
        insert⁺(acc, o, x)
    end


construct(args::Vararg{Pair}) = construct(Any, args...)

function construct(::Type{T}, args::Vararg{Pair}) where {T}
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
