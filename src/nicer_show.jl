# some piracy, but cannot upstream: relies on @o parsing extensions here
Accessors._shortstring(prev, o::Base.Splat) = "$(o.f)($prev...)"
Accessors._shortstring(prev, o::Returns) = sprint(show, o.value)

barebones_string(optic::Base.Splat) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::Union{Base.Fix1,Base.Fix2}) = sprint(Accessors.show_optic, optic; context=:compact => true)
barebones_string(optic::typeof(identity)) = "_"
barebones_string(optic) = @p let
    sprint(Accessors.show_optic, optic; context=:compact => true)
    replace(__, "_." => "", "_[" => "[")
end



# XXX: piracy, should upstream the changes
function Accessors.show_optic(io::IO, optic)
    opts = deopcompose(optic)
    inner = Iterators.takewhile(x -> applicable(Accessors._shortstring, "", x), opts)
    outer = Iterators.dropwhile(x -> applicable(Accessors._shortstring, "", x), opts)
    if !isempty(outer)
        show(io, opcompose(outer...))
    end
    if !isempty(inner) && !isempty(outer)
        print(io, " ∘ ")
    end
    if !isempty(inner)
        shortstr = reduce(inner; init=("_", false)) do (prev, need_parens_prev), o
            # if _need_parens is true for this o and the one before, wrap the previous one in parentheses
            if need_parens_prev && Accessors._need_parens(o)
                prev = "($prev)"
            end
            Accessors._shortstring(prev, o), Accessors._need_parens(o)
        end |> first
        if get(io, :compact, false)
            print(io, shortstr)
        else
            print(io, "(@o ", shortstr, ")")
        end
    end
end
