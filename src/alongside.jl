struct AlongsideOptic{OS}
    optics::OS
end

Accessors.OpticStyle(::Type{<:AlongsideOptic}) = Accessors.ModifyBased()

Accessors.getall(obj, ao::AlongsideOptic{<:Tuple}) =
    map(Tuple(obj), ao.optics) do obj, opt
        getall(obj, opt)
    end |> _reduce_concat

# without @generated: doesn't infer when nested
# function Accessors.modify(f, obj::Union{Tuple,NamedTuple}, ao::AlongsideOptic{<:Tuple})
#     @modify(Tuple(obj)) do tup
#         map(tup, ao.optics) do obj, opt
#             modify(f, obj, opt)
#         end
#     end
# end

# with @generated:
@generated function Accessors.modify(f, obj::Union{Tuple,NamedTuple}, ao::AlongsideOptic{OS}) where {OS<:Tuple}
    quote
        tup = Tuple(obj)
        res = ($(ntuple(fieldcount(OS)) do i
            :( modify(f, tup[$i], ao.optics[$i]) )
        end...),)
        set(obj, Tuple, res)
    end
end

Accessors.set(obj::Tuple, ::Type{Tuple}, val::Tuple) = val
Accessors.set(obj::NamedTuple{KS}, ::Type{Tuple}, val::Tuple) where {KS} = NamedTuple{KS}(val)

Accessors.getall(obj, ao::AlongsideOptic) = error("not supported")
Accessors.modify(f, obj, ao::AlongsideOptic) = error("not supported")

function Base.show(io::IO, co::AlongsideOptic{<:Tuple})
    print(io, "along(")
    for (i, o) in enumerate(co.optics)
        i == 1 || print(io, " | ")
        show(io, o)
    end
    print(io, ")")
end
Base.show(io::IO, ::MIME"text/plain", optic::AlongsideOptic{<:Tuple}) = show(io, optic)
