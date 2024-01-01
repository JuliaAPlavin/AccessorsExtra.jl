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
    setall(obj, co, map(f, getall(obj, co)))
end

function Accessors.setall(obj, co::ConcatOptics, vals)
    lengths = map(co.optics) do o
        Accessors._staticlength(getall(obj, o))
    end
    vs = Accessors.to_nested_shape(vals, Val(lengths), Val(2))
    foldl(zip(co.optics, vs); init=obj) do obj, (o, vss)
        setall(obj, o, vss)
    end
end
