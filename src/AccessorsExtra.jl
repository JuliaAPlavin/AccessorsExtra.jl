module AccessorsExtra

using Reexport
@reexport using Accessors
using CompositionsBase
import Accessors: set, modify, delete, insert, getall, setall, OpticStyle, SetBased, ModifyBased, @optic
using DataPipes
@reexport using ConstructionBase
using InverseFunctions
using Accessors: MacroTools

export
    PartsOf,
    ⩓, ⩔,
    concat, ++, @optics, @optic₊, ConcatOptics,
    @replace, @push, @pushfirst, @pop, @popfirst,
    @getall, @setall,
    construct, @construct,
    RecursiveOfType,
    keyed, enumerated, selfcontext, stripcontext, hascontext,
    maybe, osomething, oget, hasoptic, @maybe, @oget, @osomething,
    modifying, onget, onset, ongetset,
    FlexIx,
    get_steps, logged

include("utils.jl")
include("fixargs.jl")
include("concatoptic.jl")
include("overrides.jl")
include("and_or.jl")
include("keyvalues.jl")
include("flexix.jl")
include("propertyfunction.jl")
include("slicing.jl")
include("recursive.jl")
include("context.jl")
include("modifymany.jl")
include("maybe.jl")
include("partsof.jl")
include("funclenses.jl")
include("regex.jl")
include("replace.jl")
include("moremacros.jl")
include("construct.jl")
include("bystep.jl")
include("testing.jl")

include("../ext/LinearAlgebraExt.jl")


function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f === construct
                println(io); println(io)
                T = argtypes[1]
                # T isa Type || println(io, "First argument to `construct` should be a type, got $T")
                IU = get(Base.loaded_modules, Base.PkgId(Base.UUID("b77e0a4c-d291-57a0-90e8-8db25a27a240"), "InteractiveUtils"), nothing)
                isnothing(IU) && (println(io, "Load InteractiveUtils for more hints"); return)
                argstrs = map(argtypes[2:end]) do at
                    at isa Type{<:Pair} ? "::$(at.parameters[1]) => ..." : "not a Pair! $at"
                end
                println(io, "Called as:\nconstruct($T, $(join(argstrs, ", ")))\n")
                println(io, "Available for construct($T):")
                for m in IU.methodswith(Type{<:T}, construct; supertypes=false)
                    println(io, m)
                end
            end
        end
    end
end


Accessors._shortstring(prev, o::Returns) = sprint(show, o.value)
Accessors._shortstring(prev, os::OSomething) =
    (prev == "_" ? "" : "(") * join(map(barebones_string, os.os), " || ") * (prev == "_" ? "" : ") ∘ $(prev)")

barebones_string(optic::Base.Splat) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::Union{Base.Fix1,Base.Fix2}) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::typeof(identity)) = "_"
barebones_string(optic) = @p let
    sprint(Accessors.show_optic, optic; context=:compact => true)
    replace(__, "_." => "", "_[" => "[")
end


Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view)}, val) = setindex!(obj, val, lens.x)
Base.@propagate_inbounds set(obj, lens::Base.Fix2{typeof(view), <:Integer}, val::AbstractArray{<:Any, 0}) = setindex!(obj, only(val), lens.x)


# set getfields(): see https://github.com/JuliaObjects/Accessors.jl/pull/57
@generated function set(obj::T, o::typeof(getfields), val::NamedTuple{KS,VS}) where {T, KS, VS}
    @assert fieldnames(T) == KS
    # assume that constructorof(T)(val...) gives the correct type
    # construct this type with specified field values
    newT = quote
        newT = Core.Compiler.return_type(constructorof(T), $VS)
        isconcretetype(newT) ? newT : typeof(constructorof(T)(val...))
    end
    return Expr(:new, newT, map(k -> :(val.$k), KS)...)
    # return Expr(:new, :(Core.Compiler.return_type(constructorof(T), Tuple{typeof.(values(val))...})), map(k -> :(val.$k), KS)...)
end
set(obj, o::Base.Fix2{typeof(getfield)}, val) = @set getfields(obj)[o.x] = val
set(obj, o::Base.Fix2{typeof(getfield), Val{F}}, val) where {F} = @set getfields(obj) |> PropertyLens{F}() = val

# inverse getindex
# XXX: should only be defined for a separate type, something like Bijection
# otherwise not really an inverse
InverseFunctions.inverse(f::Base.Fix1{typeof(getindex)}) = Base.Fix2(findfirst, f.x) ∘ isequal
InverseFunctions.inverse(f::ComposedFunction{<:Base.Fix2{typeof(findfirst)}, typeof(isequal)}) = Base.Fix1(getindex, f.outer.x)

# https://github.com/JuliaObjects/Accessors.jl/pull/103
function set(obj, f::Base.Fix1{typeof(getindex)}, val)
    ix = findfirst(isequal(val), f.x)
    ix === nothing && throw(ArgumentError("value $val not found in $(f.x)"))
    return ix
end

Accessors._shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"

# unambiguous for unitranges, but tension with general array @set first(x)...
# piracy
set(r::AbstractUnitRange, ::typeof(first), x) = x:last(r)
set(r::AbstractUnitRange, ::typeof(last),  x) = first(r):x
set(r::Base.OneTo, ::typeof(last), x) = Base.OneTo(x)
set(r::Base.OneTo, ::typeof(length), x) = Base.OneTo(x)


struct ConstrainedLens{O,MO}
    o::O
    mo::MO
end

modifying(mo) = o -> ConstrainedLens(o, mo)

(c::ConstrainedLens)(x) = c.o(x)
set(obj::Complex, c::ConstrainedLens{typeof(angle),typeof(real)}, val) = set(obj, c.mo, imag(obj)/tan(val))
set(obj::Complex, c::ConstrainedLens{typeof(angle),typeof(imag)}, val) = set(obj, c.mo, real(obj)*tan(val))


struct onset{F}
    f::F
end
@inline (o::onset)(x) = x
@inline set(obj, o::onset, val) = o.f(val)

struct onget{F}
    f::F
end
@inline (o::onget)(x) = o.f(x)
@inline set(obj, o::onget, val) = val

ongetset(f) = onget(f) ∘ onset(f)


# should probably try to upstream:
InverseFunctions.inverse(::typeof(tuple)) = only
InverseFunctions.inverse(::typeof(only)) = tuple

# min and max as well
set(obj, o::Union{Base.Fix1{typeof(max)}, Base.Fix2{typeof(max)}}, val) = val ≥ o.x ? val : throw(ArgumentError("Value $val is lower than the other `max` argument $(o.x)"))
set(obj, o::Union{Base.Fix1{typeof(min)}, Base.Fix2{typeof(min)}}, val) = val ≤ o.x ? val : throw(ArgumentError("Value $val is higher than the other `min` argument $(o.x)"))
set(obj, o::FixArgsT(clamp, (Placeholder, Any, Any)), val) = o.args[2] ≤ val ≤ o.args[3] ? val : throw(ArgumentError("Value $val is out of `clamp` bounds $(o.args[2]) .. $(o.args[3])"))

# for f in (map,)
#     for m in methods(f)
#         m.recursion_relation = Returns(true)
#     end
# end

end
