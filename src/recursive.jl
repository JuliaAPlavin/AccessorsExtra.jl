struct RecursiveOfType
    outtypes
    rectypes
    optic
end
RecursiveOfType(; out, recurse, optic) = RecursiveOfType(out, recurse, optic)

function unrecurcize(or::RecursiveOfType, ::Type{T}) where {T}
    TS = Core.Compiler.return_type(getall, Tuple{T, typeof(or.optic)})
    if TS <: Tuple
        map(enumerate(fieldtypes(TS))) do (i, ET)
            any(rt -> ET <: rt, or.rectypes) ? unrecurcize(or, ET) :
            any(rt -> ET <: rt, or.outtypes) ? identity :
                EmptyOptic()
        end |> Tuple |> AlongsideOptic
    elseif TS <: AbstractVector
        ET = eltype(TS)
        any(rt -> ET <: rt, or.rectypes) ? unrecurcize(or, ET) ∘ Elements() :
        any(rt -> ET <: rt, or.outtypes) ? Elements() :
            EmptyOptic()
    end
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
