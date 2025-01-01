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

# todo: remove this when Accessors is released
_secondarg(_, x) = x
_esc_and_dot_name_to_broadcasted(f) = esc(f)
_esc_and_dot_name_to_broadcasted(f::Symbol) =
    if f == :.
    # eg, in @set a[:] .= 1
        # the returned function will be called as func(a, 1)
        :(Base.BroadcastFunction($_secondarg))
    elseif startswith(string(f), '.')
        # eg, in @set a[:] .+= 1 or @o _ .+ 1
        :(Base.BroadcastFunction($(esc(Symbol(string(f)[2:end])))))
    else
        esc(f)
    end


# changes from upstream:
# - call parse_obj_optic_underscore_only to allow `@o 123`
function Accessors.opticmacro(optictransform::Function, ex)
    obj, optic = parse_obj_optic_underscore_only(ex)
    if obj != esc(:_)
        msg = """Cannot parse optic $ex. Lens expressions must start with _, got $obj instead."""
        throw(ArgumentError(msg))
    end
    :($(optictransform)($optic))
end
parse_obj_optic_underscore_only(ex) =
    if tree_contains(ex, :_)
        Accessors.parse_obj_optic(ex)
    else
        esc(:_), :(Returns($(esc(ex))))
    end

# changes from upstream:
# https://github.com/JuliaObjects/Accessors.jl/pull/103
# creating:
# - ConcatOptic
# - ContainerOptic
# - FixArgs
# – PropertyFunction
# - splat
# - ⩓, ⩔, _ < _ < _ support
_parse_obj_optics(ex) = parse_obj_optics(ex)
function _parse_obj_optics(ex::Expr)
    @debug "Parsing optic" ex
    dollar_exprs = foldtree([], ex) do exs, x
        x isa Expr && x.head == :$ ?
            push!(exs, only(x.args)) :
            exs
    end
    if !isempty(dollar_exprs)
        @debug "Has dollar expressions" dollar_exprs
        length(dollar_exprs) == 1 || error("Only a single dollar-expression is supported")
        # obj is the only dollar-expression:
        obj = esc(only(dollar_exprs))
        # parse expr with an underscore instead of the dollar-expression:
        _, optics = _parse_obj_optics(postwalk(x -> x isa Expr && x.head == :$ ? :_ : x, ex))
        return obj, optics
    end

    if @capture(ex, (front_ |> back_))
        @debug "Captured front_ |> back_" front back
        obj, frontoptic = _parse_obj_optics(front)
        backoptic = try
            # allow e.g. obj |> first |> _.a.b
            obj_back, backoptic = _parse_obj_optics(back)
            if obj_back == esc(:_)
                backoptic
            else
                (esc(back),)
            end
        catch ArgumentError
            backoptic = (esc(back),)
        end
        return obj, tuple(frontoptic..., backoptic...)
    elseif @capture(ex, (left_ && right_)) || @capture(ex, (left_ || right_))
        @debug "Captured left_ && right_ or left_ || right_" left right
        objl, leftoptic = parse_obj_optic(left)
        objr, rightoptic = parse_obj_optic(right)
        @assert objl == objr
        obj = objl
        operator = Dict(:&& => ⩓, :|| => ⩔)[ex.head]
        return obj, (:($operator($leftoptic, $rightoptic)),)
    elseif Base.isexpr(ex, :comparison) && length(ex.args) == 5 && !tree_contains(ex.args[1], :_) && !tree_contains(ex.args[5], :_)
        @debug "Captured comparison"
        obj1, optic1 = parse_obj_optic(:($(ex.args[2])($(ex.args[1]), $(ex.args[3]))))
        obj2, optic2 = parse_obj_optic(:($(ex.args[4])($(ex.args[3]), $(ex.args[5]))))
        @assert obj1 == obj2
        obj = obj1
        return obj, (:($⩓($optic1, $optic2)),)
    elseif @capture(ex, front_[indices__])
        @debug "Captured front_[indices__]" front indices
        if !tree_contains(front, :_) && any(ind -> tree_contains(ind, :_), indices)
            ind = only(indices)
            @assert tree_contains(ind, :_)
            obj, frontoptic = _parse_obj_optics(ind)
            optic = :(Base.Fix1(getindex, $(esc(front))))
        else
            obj, frontoptic = _parse_obj_optics(front)
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
        @debug "Captured front_.property_" front property
        property isa Union{Int,Symbol,String} || throw(ArgumentError(
            string("Error while parsing :($ex). Second argument to `getproperty` can only be",
                   "an `Int`, `Symbol` or `String` literal, received `$property` instead.")
        ))
        obj, frontoptic = _parse_obj_optics(front)
        optic = :($PropertyLens{$(QuoteNode(property))}())
    elseif @capture(ex, f_(args__)) || @capture(ex, f_.(args__))
        is_bcast = @capture(ex, tmpf_.(tmpargs__))
        @debug "Captured f_(args__)" f args is_bcast

        args_contain_under = map(arg -> tree_contains(arg, :_), args)
        f_contains_under = tree_contains(f, :_)
        f_contains_under && any(args_contain_under) && error("Either the function or the arguments can contain an underscore, not both")
        if f_contains_under
            @assert !is_bcast
            obj, frontoptic = _parse_obj_optics(f)
            optic = :($funcvallens($(esc.(args)...),))
        elseif length(args) == 1
            arg = only(args)
            f = _esc_and_dot_name_to_broadcasted(f)
            if Base.isexpr(arg, :(...))
                obj, frontoptic = _parse_obj_optics(only(arg.args))
                optic = :(splat($f))
            else
                # regular function optic
                # broadcasted operators like .- also fall here
                obj, frontoptic = _parse_obj_optics(arg)
                optic = f
            end
        elseif any(args_contain_under)
            f = _esc_and_dot_name_to_broadcasted(f)
            if count(args_contain_under) == 1
                # single function argument is optic target - create Fix1, Fix2, or FixArgs optic
                # multi-arg broadcasts also fall here, no matter if regular function or operator
                if length(args) == 2 && !any(a -> Base.isexpr(a, :kw) || Base.isexpr(a, :parameters), args)
                    # Base.Fix1 or Fix2 is enough
                    if args_contain_under[1]
                        obj, frontoptic = _parse_obj_optics(args[1])
                        optic = :(Base.Fix2($f, $(esc(args[2]))))
                    elseif args_contain_under[2]
                        obj, frontoptic = _parse_obj_optics(args[2])
                        optic = :(Base.Fix1($f, $(esc(args[1]))))
                    end
                else
                    # need FixArgs
                    i_under = findfirst(args_contain_under)
                    obj, frontoptic = _parse_obj_optics(args[i_under])
                    @reset args[i_under] = Placeholder()
                    optic = Expr(:call, fixargs, f, esc.(args)...)
                end
            else
                # multiple function arguments are "targets" - do nothing here, will create propertyfunction below
            end
        else
            # do nothing, see extra processing below
        end
        if (@isdefined optic) && is_bcast
            optic = :(Base.BroadcastFunction($optic))
        end
    elseif Base.isexpr(ex, :macrocall)
        @debug "Captured macrocall" ex
        return esc(ex), ()
    end

    if !@isdefined optic
        @debug "No full optic parsed, will create PropertyFunction"
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
                :($PropertyFunction($props_nt, $funcbody, $(QuoteNode(ex))))
            end
        else
            # no placeholder in ex
            obj = esc(ex)
            return obj, ()
        end
    end

    return (obj, tuple(frontoptic..., optic))
end

function parse_obj_optics(ex::Expr)
    @debug "Parsing optic - outer" ex
    if Base.isexpr(ex, :tuple) || Base.isexpr(ex, :vect)
        @debug "Captured tuple or vect"
        if length(ex.args) == 1 && Base.isexpr(only(ex.args), :parameters)
            @debug "... with kwargs-like parameters"
            oex = @modify(only(ex.args).args[∗]) do arg
                @debug "Individual argument" arg
                if MacroTools.@capture arg (key_ = optic_)
                    :( $key = $Accessors.@o $optic )
                else
                    key = _extract_symbol(arg)
                    :( $key = $Accessors.@o $arg )
                end
            end
            return esc(:_), (esc(:( $ContainerOptic($oex) )),)
        else
            oex = @modify(ex.args[∗]) do arg
                @debug "Individual argument" arg
                if MacroTools.@capture arg (key_ = optic_)
                    :( $key = $Accessors.@o $optic )
                else
                    :( $Accessors.@o $arg )
                end
            end
            return esc(:_), (esc(:( $ContainerOptic($oex) )),)
        end
    elseif iscall(ex, :SVector) || iscall(ex, :MVector) || iscall(ex, :Pair) || iscall(ex, :(=>))
        @debug "Captured SVector, MVector, Pair, or =>"
        oex = @modify(ex.args[2:end][∗]) do arg
            :( $Accessors.@o $arg )
        end
        return esc(:_), (esc(:( $ContainerOptic($oex) )),)
    else
        _parse_obj_optics(ex)
    end
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
