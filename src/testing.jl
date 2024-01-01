_expr_to_symb(e::Symbol)::Symbol = e
_expr_to_symb(e::Expr)::Union{Nothing,Symbol} = eval(e)

_extract_symbol(e::Symbol) = e
function _extract_symbol(e::Expr)::Symbol
    @assert Base.isexpr(e, :.) && length(e.args) == 2 && e.args[2] isa QuoteNode
    return e.args[2].value
end
iscall(ex, f::Symbol) = Base.isexpr(ex, :call) && _extract_symbol(ex.args[1]) == f

macro allinferred(exprs...)
    funcs = @p Base.front(exprs) |> filtermap(_expr_to_symb)
    expr = last(exprs)
    expr = Accessors.MacroTools.postwalk(expr) do ex
        if any(f -> iscall(ex, f), funcs)
            :(@inferred $ex)
        else
            ex
        end
    end
    esc(expr)
end
