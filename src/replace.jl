
# replace()
_replace(obj, (from, to)::Pair) = insert(delete(obj, from), to, from(obj))
_replace(obj::NamedTuple{NS}, (from, to)::Pair{PropertyLens{A}, PropertyLens{B}}) where {NS, A, B} = NamedTuple{replace(NS, A => B)}(values(obj))

_replace(obj, optic::ComposedFunction) =
    modify(obj, optic.inner) do inner_obj
        _replace(inner_obj, optic.outer)
    end

macro replace(ex)
    obj, fromto_optics, inner_optic = if ex.head == :(=)
        @assert length(ex.args) == 2
        to, from = Accessors.parse_obj_optic.(ex.args)
        from_obj, from_optic = from
        to_obj, to_optic = to
        obj = if from_obj == to_obj
            from_obj
        elseif from_obj == esc(:_)
            to_obj
        elseif to_obj == esc(:_)
            from_obj
        else
            throw(ArgumentError("replace requires that the from and to objects are the same; got from = $(from_obj) to = $(to_obj)"))
        end
        obj, :($from_optic => $to_optic), :identity
    else
        obj, optics = Accessors.parse_obj_optics(ex)
        inner_optic = Expr(:call, Accessors.opticcompose, optics[1:end-1]...)
        assignment = optics[end]
        assignment = assignment isa Expr && assignment.head == :escape ? only(assignment.args) : assignment
        @assert assignment.head == :(=) && length(assignment.args) == 2
        to, from = Accessors.parse_obj_optic.(assignment.args)
        from_obj, from_optic = from
        to_obj, to_optic = to
        @assert from_obj == to_obj == esc(:_)
        obj, :($from_optic => $to_optic), inner_optic        
    end
    :($_replace($obj, $fromto_optics ∘ $inner_optic))
end
