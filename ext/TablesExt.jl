module TablesExt

using AccessorsExtra
using Tables

Accessors.set(x, ::typeof(columntable), v::Tables.ColumnTable) = Tables.materializer(x)(v)
Accessors.set(x, ::typeof(rowtable), v::Tables.RowTable) = Tables.materializer(x)(v)

Accessors.set(x::NamedTuple{<:Any, <:NTuple{<:Any,AbstractVector}}, ::typeof(Tables.columns), v::Tables.ColumnTable) = v
Accessors.set(x::Vector{<:NamedTuple}, ::typeof(Tables.columns), v) = rowtable(v)

Accessors.set(x::Tables.CopiedColumns, o::PropertyLens, v) = set(x, o ∘ Tables.source, v)
Accessors.insert(x::Tables.CopiedColumns, o::PropertyLens, v) = insert(x, o ∘ Tables.source, v)
Accessors.delete(x::Tables.CopiedColumns, o::PropertyLens) = delete(x, o ∘ Tables.source)

Accessors.set(x::Tables.CopiedColumns, ::typeof(Tables.source), v) = Tables.CopiedColumns(v)

end
