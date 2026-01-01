struct StopWalk
    value
end

struct ContinueWalk
    value
end

function prewalk(f, x)
    x_ = f(x)
    x_ isa StopWalk ? x_.value :
    x_ isa ContinueWalk ? prewalk(f, x_.value) :
    Accessors.MacroTools.walk(x_, x -> prewalk(f, x), identity)
end


macro allinferred(exprs...)
    funcs = @p Base.front(exprs) |> map(_expr_to_symb) |> filter(!isnothing)
    expr = last(exprs)
    expr = prewalk(expr) do ex
        if Base.isexpr(ex, :macrocall) && ex.args[1] == Symbol("@noinf")
            StopWalk(ex.args[end])
        elseif Base.isexpr(ex, :do)
            # @inferred doesn't work with do-blocks
            StopWalk(ex)
        elseif any(f -> iscall(ex, f), funcs)
            StopWalk(:(@inferred $ex))
        else
            ex
        end
    end
    esc(expr)
end

function test_construct_laws end
