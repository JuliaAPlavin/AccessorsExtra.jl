module TablesExt

using AccessorsExtra
using Tables

Accessors.set(x, ::typeof(columntable), v::Tables.ColumnTable) = Tables.materializer(x)(v)
Accessors.set(x, ::typeof(rowtable), v::Tables.RowTable) = Tables.materializer(x)(v)

Accessors.set(x::NamedTuple{<:Any, <:NTuple{<:Any,AbstractVector}}, ::typeof(Tables.columns), v::Tables.ColumnTable) = v
Accessors.set(x::Vector{<:NamedTuple}, ::typeof(Tables.columns), v) = rowtable(v)

Accessors.set(x::Tables.CopiedColumns, o::PropertyLens, v) = Tables.CopiedColumns(set(Tables.source(x), o, v))
Accessors.insert(x::Tables.CopiedColumns, o::PropertyLens, v) = Tables.CopiedColumns(insert(Tables.source(x), o, v))
Accessors.delete(x::Tables.CopiedColumns, o::PropertyLens) = Tables.CopiedColumns(delete(Tables.source(x), o))

end
