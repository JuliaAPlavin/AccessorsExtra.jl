struct RecursiveOfType
    outtypes
    rectypes
    optic
end
RecursiveOfType(; out, recurse=(Any,), optic) = RecursiveOfType(out, recurse, optic)

Accessors.OpticStyle(::Type{<:RecursiveOfType}) = Accessors.ModifyBased()

function Accessors.modify(f, obj, or::RecursiveOfType)
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

function Accessors.getall(obj, or::RecursiveOfType)
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
Accessors.OpticStyle(::Type{<:EmptyOptic}) = Accessors.ModifyBased()
Accessors.getall(obj, ::EmptyOptic) = ()
Accessors.modify(f, obj, ::EmptyOptic) = obj
Base.show(io::IO, o::EmptyOptic) = print(io, "∅")
Base.show(io::IO, ::MIME"text/plain", o::EmptyOptic) = show(io, optic)

# function unrecurcize(or::Recursive, ::Type{T}) where {T}
#     TS = Core.Compiler.return_type(getall, Tuple{T, typeof(or.optic)})
#     if TS <: Tuple
#         map(enumerate(_eltypes(TS))) do (i, ET)
#             o = IndexLens(i)
#             _ctime(or.descent_condition, ET) ?
#                 unrecurcize(or, ET) ∘ o :
#                 o
#         end |> Tuple |> ConcatOptics
#     elseif TS <: AbstractVector
#         ET = eltype(TS)
#         o = Elements()
#         _ctime(or.descent_condition, ET) ?
#             unrecurcize(or, ET) ∘ o :
#             o
#     end
# end

# _eltypes(::Type{T}) where {T <: Tuple} = fieldtypes(T)
# _eltypes(::Type{<:AbstractArray{T}}) where {T} = (T,)

# function _ctime(f, ::Type{T}) where {T}
#     v = Core.Compiler.return_type(x -> Val(f(x)), Tuple{T})
#     v <: Val || error("Cannot comptime-evaluate $f on $T. Got $v.")
#     _valt(v)
# end

# _valt(::Type{Val{V}}) where {V} = V
