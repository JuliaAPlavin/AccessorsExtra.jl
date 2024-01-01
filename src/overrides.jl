using Accessors: @capture, foldtree, need_dynamic_optic, replace_underscore, lower_index, DynamicIndexLens
import Accessors: parse_obj_optics


function parse_obj_optics(ex::Expr)
    if @capture(ex, (front_ |> back_))
        obj, frontoptic = parse_obj_optics(front)
        backoptic = try
            # allow e.g. obj |> first |> _.a.b
            obj_back, backoptic = parse_obj_optics(back)
            if obj_back == esc(:_)
                backoptic
            else
                (esc(back),)
            end
        catch ArgumentError
            backoptic = (esc(back),)
        end
        return obj, tuple(frontoptic..., backoptic...)
    elseif @capture(ex, front_[indices__])
        obj, frontoptic = parse_obj_optics(front)
        if any(need_dynamic_optic, indices)
            @gensym collection
            indices = replace_underscore.(indices, collection)
            dims = length(indices) == 1 ? nothing : 1:length(indices)
            lindices = esc.(lower_index.(collection, indices, dims))
            optic = :($DynamicIndexLens($(esc(collection)) -> ($(lindices...),)))
        else
            index = esc(Expr(:tuple, indices...))
            optic = :($IndexLens($index))
        end
    elseif @capture(ex, front_.property_)
        property isa Union{Int,Symbol,String} || throw(ArgumentError(
            string("Error while parsing :($ex). Second argument to `getproperty` can only be",
                   "an `Int`, `Symbol` or `String` literal, received `$property` instead.")
        ))
        obj, frontoptic = parse_obj_optics(front)
        optic = :($PropertyLens{$(QuoteNode(property))}())
    elseif @capture(ex, f_(front_))
        obj, frontoptic = parse_obj_optics(front)
        optic = esc(f) # function optic
    elseif @capture(ex, f_(args__))
        args_contain_under = map(args) do arg
            foldtree((yes, x) -> yes || x === :_, false, arg)
        end
        if !any(args_contain_under)
            # as if f(args...) didn't match
            obj = esc(ex)
            return obj, ()
        end
        length(args) == 2 || error("Only 1- and 2-argument functions are supported")
        sum(args_contain_under) == 1 || error("Only a single function argument can be the optic target")
        if args_contain_under[1]
            obj, frontoptic = parse_obj_optics(args[1])
            optic = :(Base.Fix2($(esc(f)), $(esc(args[2]))))
        elseif args_contain_under[2]
            obj, frontoptic = parse_obj_optics(args[2])
            optic = :(Base.Fix1($(esc(f)), $(esc(args[1]))))
        end
    else
        obj = esc(ex)
        return obj, ()
    end
    return (obj, tuple(frontoptic..., optic))
end
