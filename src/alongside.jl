struct AlongsideOptic{OS}
    optics::OS
end
Broadcast.broadcastable(o::AlongsideOptic) = Ref(o)

OpticStyle(::Type{<:AlongsideOptic}) = ModifyBased()

getall(obj, ao::AlongsideOptic{<:Tuple}) =
    map(_Tuple(obj), ao.optics) do obj, opt
        getall(obj, opt)
    end |> _reduce_concat

setall(obj, ao::AlongsideOptic{Tuple{}}, vals) = (@assert isempty(vals); obj)
function setall(obj, ao::AlongsideOptic{<:Tuple}, vals)
    modify(obj, _Tuple) do obj
        lengths = map(obj, ao.optics) do obj, opt
            Accessors._staticlength(getall(obj, opt))
        end
        vs = Accessors.to_nested_shape(vals, Val(lengths), Val(2))
        lengths = map(obj, ao.optics, vs) do obj, opt, vss
            setall(obj, opt, vss)
        end
    end
end

# without @generated: doesn't infer when nested
# function modify(f, obj::Union{Tuple,NamedTuple}, ao::AlongsideOptic{<:Tuple})
#     @modify(Tuple(obj)) do tup
#         map(tup, ao.optics) do obj, opt
#             modify(f, obj, opt)
#         end
#     end
# end

# with @generated:
@generated function modify(f, obj, ao::AlongsideOptic{OS}) where {OS<:Tuple}
    quote
        tup = _Tuple(obj)
        res = ($(ntuple(fieldcount(OS)) do i
            :( modify(f, tup[$i], ao.optics[$i]) )
        end...),)
        set(obj, _Tuple, res)
    end
end

@accessor _Tuple(x::Union{Tuple,NamedTuple,AbstractVector}) = Tuple(x)
@accessor _Tuple(x) = Tuple(getproperties(x))

getall(obj, ao::AlongsideOptic) = error("not supported")
modify(f, obj, ao::AlongsideOptic) = error("not supported")

function Base.show(io::IO, co::AlongsideOptic{<:Tuple})
    print(io, "along(")
    for (i, o) in enumerate(co.optics)
        i == 1 || print(io, " | ")
        show(io, o)
    end
    print(io, ")")
end
Base.show(io::IO, ::MIME"text/plain", optic::AlongsideOptic{<:Tuple}) = show(io, optic)
