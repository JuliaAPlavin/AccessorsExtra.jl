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
