"""    RecursiveOfType(out, optic; [recurse=Any])
"""
struct RecursiveOfType{OT,RT,O}
    outtypes::OT
    rectypes::RT
    optic::O
end
Broadcast.broadcastable(o::RecursiveOfType) = Ref(o)
RecursiveOfType(; out::Type{TO}, recurse::Type{TR}=Any, optic) where {TO,TR} =
    RecursiveOfType{Type{TO},Type{TR},typeof(optic)}(out, recurse, optic)
RecursiveOfType(out::Type{TO}; recurse::Type{TR}=Any, optic) where {TO,TR} =
    RecursiveOfType{Type{TO},Type{TR},typeof(optic)}(out, recurse, optic)
RecursiveOfType(out::Type{TO}, optic; recurse::Type{TR}=Any) where {TO,TR} =
    RecursiveOfType{Type{TO},Type{TR},typeof(optic)}(out, recurse, optic)


OpticStyle(::Type{<:RecursiveOfType}) = ModifyBased()

# see https://github.com/FluxML/Functors.jl/pull/61 for the approach and its discussion
function modify(f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_modify(var"#self#", f, o, or)
    _walk_modify(recurse, f, obj, or)
end
_walk_modify(recurse, f, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT} =
    if obj isa OT && obj isa RT
        f(modify(recurse, obj, or.optic))
    elseif obj isa RT
        modify(recurse, obj, or.optic)
    elseif obj isa OT
        f(obj)
    else
        obj
    end


function getall(obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT}
    recurse(o) = _walk_getall(var"#self#", o, or)
    _walk_getall(recurse, obj, or)
end
_walk_getall(recurse, obj, or::RecursiveOfType{Type{OT},Type{RT}}) where {OT,RT} =
    if obj isa OT && obj isa RT
        (_getall(recurse, obj, or.optic)..., obj)
    elseif obj isa RT
        _getall(recurse, obj, or.optic)
    elseif obj isa OT
        (obj,)
    else
        ()
    end
_getall(recurse, obj, optic) = @p getall(obj, optic) |> map(recurse) |> _reduce_concat


function unrecurcize(or::RecursiveOfType, ::Type{T}) where {T}
    rec_optic = if T <: or.rectypes
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
    T <: or.outtypes ?
        rec_optic ++ identity :
        rec_optic
end


struct EmptyOptic end
OpticStyle(::Type{<:EmptyOptic}) = ModifyBased()
getall(obj, ::EmptyOptic) = ()
setall(obj, ::EmptyOptic, vals) = (@assert isempty(vals); obj)
modify(f, obj, ::EmptyOptic) = obj
Base.show(io::IO, o::EmptyOptic) = print(io, "∅")
Base.show(io::IO, ::MIME"text/plain", o::EmptyOptic) = show(io, optic)
