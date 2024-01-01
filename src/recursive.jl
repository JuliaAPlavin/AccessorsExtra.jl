struct RecursiveOfType
    outtypes
    rectypes
    optic
end
RecursiveOfType(; out, recurse=(Any,), optic) = RecursiveOfType(out, recurse, optic)

OpticStyle(::Type{<:RecursiveOfType}) = ModifyBased()

function modify(f, obj, or::RecursiveOfType)
    modified = if any(t -> obj isa t, or.rectypes)
        modify(obj, or.optic) do o
            modify(f, o, or)
        end
    else
        obj
    end
    # check cond(cur) == cond(obj) somewhere?
    cur = any(t -> obj isa t, or.outtypes) ? f(modified) : modified
end

function getall(obj, or::RecursiveOfType)
    res_inner = if any(t -> obj isa t, or.rectypes)
        map(getall(obj, or.optic)) do o
            getall(o, or)
        end |> _reduce_concat
    else
        ()
    end
    res_cur = any(t -> obj isa t, or.outtypes) ? (obj,) : ()
    return Accessors._concat(res_inner, res_cur)
end


function unrecurcize(or::RecursiveOfType, ::Type{T}) where {T}
    rec_optic = if any(rt -> T <: rt, or.rectypes)
        TS = Core.Compiler.return_type(getall, Tuple{T, typeof(or.optic)})
        if TS == Union{} || !isconcretetype(TS)
            error("Cannot recurse on $T |> $(or.optic): got $TS")
        elseif TS <: Tuple
            map(enumerate(fieldtypes(TS))) do (i, ET)
                unrecurcize(or, ET)
            end |> Tuple |> AlongsideOptic
        elseif TS <: AbstractVector
            ET = eltype(TS)
            unrecurcize(or, ET) ∘ Elements()
        end
    else
        EmptyOptic()
    end
    any(rt -> T <: rt, or.outtypes) ?
        rec_optic ++ identity :
        rec_optic
end


struct EmptyOptic end
OpticStyle(::Type{<:EmptyOptic}) = ModifyBased()
getall(obj, ::EmptyOptic) = ()
modify(f, obj, ::EmptyOptic) = obj
Base.show(io::IO, o::EmptyOptic) = print(io, "∅")
Base.show(io::IO, ::MIME"text/plain", o::EmptyOptic) = show(io, optic)
