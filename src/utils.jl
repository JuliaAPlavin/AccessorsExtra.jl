_expr_to_symb(e::Symbol)::Symbol = e
_expr_to_symb(e::Expr)::Union{Nothing,Symbol} = eval(e)

_extract_symbol(e::Symbol) = e
function _extract_symbol(e::Expr)::Union{Symbol,Nothing}
    Base.isexpr(e, :curly) && return _extract_symbol(e.args[1])
    Base.isexpr(e, :.) || return nothing
    @assert Base.isexpr(e, :.) && length(e.args) == 2 && e.args[2] isa QuoteNode
    return e.args[2].value
end
iscall(ex, f::Symbol) = Base.isexpr(ex, :call) && _extract_symbol(ex.args[1]) == f
