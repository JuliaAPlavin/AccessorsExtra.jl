module TablesExt

using AccessorsExtra
using Tables

Accessors.set(x, ::typeof(columntable), v::Tables.ColumnTable) = Tables.materializer(x)(v)
Accessors.set(x, ::typeof(rowtable), v::Tables.RowTable) = Tables.materializer(x)(v)

Accessors.set(x::NamedTuple{<:Any, <:NTuple{<:Any,AbstractVector}}, ::typeof(Tables.columns), v::Tables.ColumnTable) = v
Accessors.set(x::Vector{<:NamedTuple}, ::typeof(Tables.columns), v) = rowtable(v)

Accessors.set(x::Tables.CopiedColumns, o::PropertyLens, v) = modify(src -> set(src, o, v), x, Tables.source)
Accessors.insert(x::Tables.CopiedColumns, o::PropertyLens, v) = modify(src -> insert(src, o, v), x, Tables.source)
Accessors.delete(x::Tables.CopiedColumns, o::PropertyLens) = modify(src -> delete(src, o), x, Tables.source)

Accessors.set(x::Tables.CopiedColumns, ::typeof(Tables.source), v) = Tables.CopiedColumns(v)

end
