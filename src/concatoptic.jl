struct ConcatOptics{OS}
    optics::OS
end

concat(optics...) = ConcatOptics(optics)
concat(; optics...) = ConcatOptics(values(optics))
const ++ = concat

Accessors.OpticStyle(::Type{<:ConcatOptics}) = Accessors.ModifyBased()

macro optics(exs...)
    optic_exs = map(exs) do ex
        :($Accessors.@optic($ex))
    end
    :( $concat($(optic_exs...)) ) |> esc
end


function Accessors.getall(obj, co::ConcatOptics)
    map(co.optics) do o
        getall(obj, o)
    end |> _reduce_concat
end

_reduce_concat(xs) = Accessors._reduce_concat(xs)
_reduce_concat(xs::NamedTuple) = map(only, xs)

function Accessors.modify(f, obj, co::ConcatOptics)
    foldl(co.optics; init=obj) do obj, o
        modify(f, obj, o)
    end
end

function Accessors.setall(obj, co::ConcatOptics{<:Tuple}, vals)
    lengths = map(co.optics) do o
        Accessors._staticlength(getall(obj, o))
    end
    vs = Accessors.to_nested_shape(vals, Val(lengths), Val(2))
    foldl(map(tuple, co.optics, vs); init=obj) do obj, (o, vss)
        setall(obj, o, vss)
    end
end

function Accessors.setall(obj, co::ConcatOptics{<:NamedTuple}, vals::NamedTuple{KS}) where {KS}
    foreach(NamedTuple{KS}(co.optics), vals) do o, vss
        @assert length(getall(obj, o)) == 1
    end
    foldl(map(tuple, NamedTuple{KS}(co.optics), vals); init=obj) do obj, (o, vss)
        set(obj, o, vss)
    end
end


function Base.show(io::IO, co::ConcatOptics{<:Tuple})
    print(io, "(")
    for (i, o) in enumerate(co.optics)
        i == 1 || print(io, " ++ ")
        show(io, o)
    end
    print(io, ")")
end
Base.show(io::IO, ::MIME"text/plain", optic::ConcatOptics{<:Tuple}) = show(io, optic)


# works? but not sure if it's useful ie better than just using ++

# using FlexiGroups
# using Accessors: deopcompose
# import Accessors: opcompose

# opcompose() = identity

# export batchize
# function batchize(co::ConcatOptics)
#     @p let
#         co.optics
#         map() do _
#             parts = deopcompose(_)
#             (; first=first(parts), rest=opcompose(Base.tail(parts)...))
#         end
#         group(_.first)
#         map() do __
#             map(_.rest)
#             Tuple
#             ConcatOptics
#         end
#         values(__) .∘ keys(__)
#         concat(__...)
#     end
# end
