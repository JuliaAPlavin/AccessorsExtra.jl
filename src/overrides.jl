using Accessors: @capture, foldtree, postwalk, need_dynamic_optic, replace_underscore, lower_index, DynamicIndexLens
import Accessors: parse_obj_optics


# https://github.com/JuliaObjects/Accessors.jl/pull/103
tree_contains(ex, parts::Tuple) = foldtree((yes, x) -> yes || x ∈ parts, false, ex)
tree_contains(ex, part) = tree_contains(ex, (part,))


# changes from upstream:
# https://github.com/JuliaObjects/Accessors.jl/pull/55
# https://github.com/JuliaObjects/Accessors.jl/pull/103
# FixArgs handling
function parse_obj_optics(ex::Expr)
    dollar_exprs = foldtree([], ex) do exs, x
        x isa Expr && x.head == :$ ?
            push!(exs, only(x.args)) :
            exs
    end
    if !isempty(dollar_exprs)
        length(dollar_exprs) == 1 || error("Only a single dollar-expression is supported")
        # obj is the only dollar-expression:
        obj = esc(only(dollar_exprs))
        # parse expr with an underscore instead of the dollar-expression:
        _, optics = parse_obj_optics(postwalk(x -> x isa Expr && x.head == :$ ? :_ : x, ex))
        return obj, optics
    end

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
        if !tree_contains(front, :_) && any(ind -> tree_contains(ind, :_), indices)
            ind = only(indices)
            if tree_contains(ind, :_)
                obj, frontoptic = parse_obj_optics(ind)
                optic = :(Base.Fix1(getindex, $(esc(front))))
            end
        else
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
        end
    elseif @capture(ex, front_.property_)
        property isa Union{Int,Symbol,String} || throw(ArgumentError(
            string("Error while parsing :($ex). Second argument to `getproperty` can only be",
                   "an `Int`, `Symbol` or `String` literal, received `$property` instead.")
        ))
        obj, frontoptic = parse_obj_optics(front)
        optic = :($PropertyLens{$(QuoteNode(property))}())
    elseif @capture(ex, f_(front_))
        if !tree_contains(f, :_)
            obj, frontoptic = parse_obj_optics(front)
            optic = esc(f) # function optic
        else
            obj, frontoptic = parse_obj_optics(f)
            optic = funcvallens(front)
        end
    elseif @capture(ex, f_(args__))
        # if Base.isexpr(first(args), :parameters)
        #     args = vcat(args[2:end], first(args).args)
        # end
        args_contain_under = map(arg -> tree_contains(arg, :_), args)
        if !any(args_contain_under)
            # as if f(args...) didn't match
            obj = esc(ex)
            return obj, ()
        end
        sum(args_contain_under) == 1 || error("Only a single function argument can be the optic target")
        if length(args) == 2 && !any(a -> Base.isexpr(a, :kw) || Base.isexpr(a, :parameters), args)
            # Base.Fix1 or Fix2 is enough
            if args_contain_under[1]
                obj, frontoptic = parse_obj_optics(args[1])
                optic = :(Base.Fix2($(esc(f)), $(esc(args[2]))))
            elseif args_contain_under[2]
                obj, frontoptic = parse_obj_optics(args[2])
                optic = :(Base.Fix1($(esc(f)), $(esc(args[1]))))
            end
        else
            # need FixArgs
            i_under = findfirst(args_contain_under)
            obj, frontoptic = parse_obj_optics(args[i_under])
            @reset args[i_under] = Placeholder()
            optic = Expr(:call, fixargs, esc(f), esc.(args)...)
            dump(optic)
        end
    else
        obj = esc(ex)
        return obj, ()
    end
    return (obj, tuple(frontoptic..., optic))
end
