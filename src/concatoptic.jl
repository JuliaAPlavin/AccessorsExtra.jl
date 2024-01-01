struct ConcatOptics{OS}
    optics::OS
end
Broadcast.broadcastable(o::ConcatOptics) = Ref(o)

concat(optics...) = ConcatOptics(optics)
concat(; optics...) = ConcatOptics(values(optics))
const ++ = concat

OpticStyle(::Type{<:ConcatOptics}) = ModifyBased()

macro optics(exs...)
    optic_exs = map(exs) do ex
        :($Accessors.@optic($ex))
    end
    :( $concat($(optic_exs...)) ) |> esc
end


function getall(obj, co::ConcatOptics)
    map(co.optics) do o
        getall(obj, o)
    end |> _reduce_concat
end

_reduce_concat(xs) = Accessors._reduce_concat(xs)
_reduce_concat(xs::NamedTuple) = map(only, xs)

_foldl(f, xs::NamedTuple; init) = _foldl(f, values(xs); init)
_foldl(f, xs::Tuple{}; init) = init
_foldl(f, xs::Tuple; init) = _foldl(f, Base.tail(xs); init=f(init, first(xs)))

function modify(f, obj, co::ConcatOptics)
    _foldl(co.optics; init=obj) do obj, o
        modify(f, obj, o)
    end
end

delete(obj, os::ConcatOptics) = _foldl(delete, os.optics; init=obj)

function setall(obj, co::ConcatOptics{<:Tuple}, vals)
    lengths = map(co.optics) do o
        Accessors._staticlength(getall(obj, o))
    end
    vs = Accessors.to_nested_shape(vals, Val(lengths), Val(2))
    foldl(map(tuple, co.optics, vs); init=obj) do obj, (o, vss)
        setall(obj, o, vss)
    end
end

setall(obj, co::ConcatOptics{<:NamedTuple}, vals) = 
    if isempty(vals)
        setall(obj, co, (;))
    else
        error("setall for ConcatOptic{<:NamedTuple}: expected NamedTuple as values, got $(typeof(vals))")
    end

function setall(obj, co::ConcatOptics{<:NamedTuple}, vals::NamedTuple{KS}) where {KS}
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


struct ContainerOptic{O}
    optics::O
end

(os::ContainerOptic{<:Union{Tuple,NamedTuple,AbstractArray,Dict,Pair}})(obj) =
    @modify(o -> o(obj), values($(os.optics))[∗])

function set(obj, os::ContainerOptic{<:Union{Tuple,Pair,AbstractArray}}, vals::Union{Tuple,Pair,AbstractArray})
    length(os.optics) == length(vals) || throw(DimensionMismatch("length mismatch between optics ($(length(os))) and values ($(length(vals)))"))
    foldl(map(tuple, os.optics, vals); init=obj) do obj, (o, v)
        set(obj, o, v)
    end
end
set(obj, os::ContainerOptic{<:NamedTuple{KS}}, vals) where {KS} =
    foldl(map(tuple, os.optics, NamedTuple{KS}(vals)); init=obj) do obj, (o, v)
        set(obj, o, v)
    end
set(obj, os::ContainerOptic{<:Dict}, vals) =
    foldl(pairs(os.optics); init=obj) do obj, (k, o)
        v = vals[k]
        set(obj, o, v)
    end

macro optic₊(ex)
    process_optic₊(ex) |> esc
end

function process_optic₊(ex)
    if Base.isexpr(ex, :tuple) || Base.isexpr(ex, :vect)
        oex = @modify(ex.args[∗]) do arg
            if MacroTools.@capture arg (key_ = optic_)
                :( $key = $(process_optic₊(optic)) )
            else
                process_optic₊(arg)
            end
        end
        :( $ContainerOptic($oex) )
    elseif iscall(ex, :SVector) || iscall(ex, :MVector) || iscall(ex, :Pair) || iscall(ex, :(=>))
        oex = @modify(ex.args[2:end][∗]) do arg
            process_optic₊(arg)
        end
        :( $ContainerOptic($oex) )
    else
        :( $Accessors.@optic $ex )
    end
end


# ConcatOptic - the only optic with getall()::NamedTuple (?)
# requires these:
Accessors._staticlength(::NamedTuple{KS}) where {KS} = Val(length(KS))
Accessors._concat(a::Tuple, b::NamedTuple) = (a..., b...)
Accessors._concat(a::NamedTuple, b::Tuple) = (a..., b...)
Accessors._concat(a::NamedTuple, b::NamedTuple) = (a..., b...)


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
