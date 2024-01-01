struct ConcatOptics{OS}
    optics::OS
end

concat(optics...) = ConcatOptics(optics)
const ++ = concat

Accessors.OpticStyle(::Type{<:ConcatOptics}) = Accessors.ModifyBased()


function Accessors.getall(obj, co::ConcatOptics)
    map(co.optics) do o
        getall(obj, o)
    end |> Accessors._reduce_concat
end

function Accessors.modify(f, obj, co::ConcatOptics)
    foldl(co.optics; init=obj) do obj, o
        modify(f, obj, o)
    end
end

function Accessors.setall(obj, co::ConcatOptics, vals)
    lengths = map(co.optics) do o
        Accessors._staticlength(getall(obj, o))
    end
    vs = Accessors.to_nested_shape(vals, Val(lengths), Val(2))
    foldl(map(tuple, co.optics, vs); init=obj) do obj, (o, vss)
        setall(obj, o, vss)
    end
end


function Base.show(io::IO, co::ConcatOptics)
    for (i, o) in enumerate(co.optics)
        i == 1 || print(io, " ++ ")
        show(io, o)
    end
end
Base.show(io::IO, ::MIME"text/plain", optic::ConcatOptics) = show(io, optic)
