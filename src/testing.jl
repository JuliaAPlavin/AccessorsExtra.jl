macro allinferred(exprs...)
    funcs = Base.front(exprs)
    expr = last(exprs)
    expr = Accessors.MacroTools.postwalk(expr) do ex
        if any(f -> Accessors.MacroTools.iscall(ex, f), funcs)
            :(@inferred $ex)
        else
            ex
        end
    end
    esc(expr)
end
