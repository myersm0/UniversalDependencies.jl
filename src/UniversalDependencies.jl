module UniversalDependencies

const UD = UniversalDependencies
export UD

include("types.jl")
include("parse.jl")
include("write.jl")
include("accessors.jl")
include("display.jl")
include("arcs.jl")

include("styles.jl")
export DisplayStyle, TableStyle, CompactStyle, ArcStyle, AutoStyle
export render

include("tables.jl")

end
