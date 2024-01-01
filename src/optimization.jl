struct OptArgs{TS}
    specs::TS
    OptArgs(specs...) = new{typeof(specs)}(specs)
end

optic(v::OptArgs) = AccessorsExtra.ConcatOptics(map(first, v.specs))
rawu(x, v::OptArgs) = getall(x, optic(v))
fromrawu(u, x0, v::OptArgs) = setall(x0, optic(v), u)
rawfunc(f, x0, v::OptArgs) = (u, p) -> f(fromrawu(u, x0, v), p)
rawbounds(x0, v::OptArgs, AT=nothing) = @p let
    v.specs
    map(fill(_[2], length(getall(x0, _[1]))))
    reduce(vcat)
    (lb=_convert(AT, minimum.(__)), ub=_convert(AT, maximum.(__)))
end


struct OptCons{TC,TS}
    ctype::TC
    specs::TS
    
    OptCons(CT::Union{Type,Nothing}, specs...) = new{typeof(CT), typeof(specs)}(CT, specs)
    OptCons(specs...) = OptCons(nothing, specs...)
end
ConstructionBase.constructorof(::Type{<:OptCons}) = (ctype, specs) -> OptCons(ctype, specs...)

rawconsbounds(c::OptCons) = @p let
    c.specs
    map(_[2])
    (lcons=_convert(c.ctype, minimum.(__)), ucons=_convert(c.ctype, maximum.(__)))
end

# rawcons(cons::OptCons, x0, v::OptArgs) = function(u, p)
# 	x = fromrawu(u, x0, v)
# 	map(cons.specs) do (consfunc, consint)
# 		consfunc(x, p)
# 	end |> cons.ctype
# end

_apply(f, args...) = f(args...)

rawcons(cons::OptCons, x0, v::OptArgs) = function(res, u, p)
    x = fromrawu(u, x0, v)
    res .= _apply.(first.(cons.specs), (x,), (p,))
end

Base.summary(cons::OptCons, x, p) = @p let
    cons.specs
    map(enumerate(__)) do (i, (f, int))
        v = f(x, p)
        "cons #$i: $v $(v ∈ int ? '∈' : '∉') $int"
    end
    join(__, '\n')
    Text
end


struct OptProblemSpec{F,D,U,X0,VS<:OptArgs,CS<:Union{OptCons,Nothing}}
    func::F
    data::D
    utype::U
    x0::X0
    vars::VS
    cons::CS
end

function OptProblemSpec(f::Base.Fix2, utype::Type, x0, vars::OptArgs, cons::OptCons)
    cons = @set cons.ctype = something(cons.ctype, utype)
    OptProblemSpec(f.f, f.x, utype, x0, vars, cons)
end
OptProblemSpec(f::Base.Fix2, utype::Union{Type,Nothing}, x0, vars::OptArgs, cons::Union{OptCons,Nothing}) = OptProblemSpec(f.f, f.x, utype, x0, vars, cons)
OptProblemSpec(f::Base.Fix2, utype::Union{Type,Nothing}, x0, vars::OptArgs) = OptProblemSpec(f, utype, x0, vars, nothing)
OptProblemSpec(f::Base.Fix2, x0, vars::OptArgs) = OptProblemSpec(f, nothing, x0, vars)
OptProblemSpec(f::Base.Fix2, x0, vars::OptArgs, cons::Union{OptCons,Nothing}) = OptProblemSpec(f, nothing, x0, vars, cons)

rawfunc(s::OptProblemSpec) = rawfunc(s.func, s.x0, s.vars)
rawdata(s::OptProblemSpec) = s.data

rawu(s::OptProblemSpec) = _convert(s.utype, rawu(s.x0, s.vars))
rawbounds(s::OptProblemSpec) = rawbounds(s.x0, s.vars, s.utype)
rawconsbounds(s::OptProblemSpec) = rawconsbounds(s.cons)
rawcons(s::OptProblemSpec) = rawcons(s.cons, s.x0, s.vars)
fromrawu(u, s::OptProblemSpec) = fromrawu(u, s.x0, s.vars)
solobj(sol, s) = fromrawu(sol.u, s)


_convert(::Nothing, x) = x

_convert(T::Type{<:Tuple}, x::Tuple) = convert(T, x)
_convert(T::Type{<:Vector}, x::Tuple) = convert(T, collect(x))
_convert(T::Type{<:AbstractVector}, x::Tuple) = convert(T, x)  # SVector, MVector

_convert(T::Type{<:Tuple}, x::AbstractVector) = T(x...)
_convert(T::Type{<:Vector}, x::AbstractVector) = convert(T, x)
_convert(T::Type{<:AbstractVector}, x::AbstractVector) = T(x...)  # SVector, MVector
