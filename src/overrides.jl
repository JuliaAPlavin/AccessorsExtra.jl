using Accessors: @capture, foldtree, postwalk, need_dynamic_optic, replace_underscore, lower_index, DynamicIndexLens
import Accessors: parse_obj_optics


# https://github.com/JuliaObjects/Accessors.jl/pull/103
tree_contains(ex, parts::Tuple) = foldtree((yes, x) -> yes || x ∈ parts, false, ex)
tree_contains(ex, part) = tree_contains(ex, (part,))

struct IgnoreChildren
    value
end

foldtree_pre(op, init, x) = op(init, x)
function foldtree_pre(op, init, ex::Expr)
    curval = op(init, ex)
    curval isa IgnoreChildren && return curval.value
    return foldl((acc, x) -> foldtree_pre(op, acc, x), ex.args; init=curval)
end


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
            @assert tree_contains(ind, :_)
            obj, frontoptic = parse_obj_optics(ind)
            optic = :(Base.Fix1(getindex, $(esc(front))))
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
    elseif @capture(ex, f_(args__))
        args_contain_under = map(arg -> tree_contains(arg, :_), args)
        f_contains_under = tree_contains(f, :_)
        f_contains_under && any(args_contain_under) && error("Either the function or the arguments can contain an underscore, not both")
        if f_contains_under
            obj, frontoptic = parse_obj_optics(f)
            optic = funcvallens(args...)
        elseif length(args) == 1
            arg = only(args)
            if Base.isexpr(arg, :(...))
                obj, frontoptic = parse_obj_optics(only(arg.args))
                optic = :(splat($(esc(f))))
            else
                # regular function optic
                obj, frontoptic = parse_obj_optics(arg)
                optic = esc(f)
            end
        elseif any(args_contain_under)
            if count(args_contain_under) == 1
                # single function argument is optic target - create Fix1, Fix2, or FixArgs optic
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
                end
            else
                # multiple function arguments are "targets" - do nothing here, will create propertyfunction below
            end
        else
            # do nothing, see extra processing below
        end
    end

    if !@isdefined optic
        if tree_contains(ex, :_)
            # placeholder in ex, but doesn't match any of the known forms
            # try creating a propertyfunction if possible
            props = foldtree_pre(Any[], ex) do acc, ex
                # XXX: catches all "_.prop" code, even within other macros
                
                # can this be done for arbitrary nesting?
                if @capture(ex, front_.p1_.p2_.p3_.p4_) && front == :_
                    push!(acc, (p1,p2,p3,p4))
                    return IgnoreChildren(acc)
                elseif @capture(ex, front_.p1_.p2_.p3_) && front == :_
                    push!(acc, (p1,p2,p3))
                    return IgnoreChildren(acc)
                elseif @capture(ex, front_.p1_.p2_) && front == :_
                    push!(acc, (p1,p2))
                    return IgnoreChildren(acc)
                elseif @capture(ex, front_.p1_) && front == :_
                    push!(acc, (p1,))
                    return IgnoreChildren(acc)
                elseif ex == :_
                    push!(acc, ())
                else
                    acc
                end
            end |> unique
            props_nt = aggregate_props(props)

            obj = esc(:_)
            frontoptic = ()
            arg = gensym(:_)
            funcbody = :($(esc(arg)) -> $(esc(replace_underscore(ex, arg))))
            optic = if props_nt == Placeholder()
                funcbody
            else
                :($PropertyFunction($props_nt, $funcbody))
            end
        else
            # no placeholder in ex
            obj = esc(ex)
            return obj, ()
        end
    end

    return (obj, tuple(frontoptic..., optic))
end

function aggregate_props(props)
    if any(isempty, props)
        return Placeholder()
    end
    byfirst = Dict{Symbol, Vector{Any}}()
    for ps in props
        push!(get!(byfirst, first(ps), []), Base.tail(ps))
    end
    byfirst_nested = modify(byfirst, Elements() ∘ values) do rests
        aggregate_props(rests)
    end
    (; byfirst_nested...)
end
