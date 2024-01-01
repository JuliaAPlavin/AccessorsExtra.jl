# see https://github.com/JuliaLang/julia/pull/46453, but here the implementation is different

function Accessors.setindex(t::Tuple, v, inds::AbstractVector{<:Integer})
    ntuple(length(t)) do i
        ix = findfirst(==(i), inds)
        isnothing(ix) ? t[i] : v[ix]
    end
end
