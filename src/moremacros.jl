using Accessors: parse_obj_optic


push(obj, optic, val) = insert(obj, last ∘ optic, val)
macro push(ref, val)
    obj, optic = parse_obj_optic(ref)
    val = esc(val)
    :($push($obj, $optic, $val))
end

pushfirst(obj, optic, val) = insert(obj, first ∘ optic, val)
macro pushfirst(ref, val)
    obj, optic = parse_obj_optic(ref)
    val = esc(val)
    :($pushfirst($obj, $optic, $val))
end

pop(obj, optic) = delete(obj, last ∘ optic)
macro pop(ref)
    obj, optic = parse_obj_optic(ref)
    :($pop($obj, $optic))
end

popfirst(obj, optic) = delete(obj, first ∘ optic)
macro popfirst(ref)
    obj, optic = parse_obj_optic(ref)
    :($popfirst($obj, $optic))
end

macro getall(ref)
    obj, optic = parse_obj_optic(ref)
    :($getall($obj, $optic))
end

macro setall(ex)
    @assert ex.head == :(=)
    ref, val = ex.args
    obj, optic = parse_obj_optic(ref)
    val = esc(val)
    :($setall($obj, $optic, $val))
end
