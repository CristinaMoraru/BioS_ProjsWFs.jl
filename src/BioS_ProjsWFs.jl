module BioS_ProjsWFs

# external libs
using DataFrames
using Serialization
using CSV

# my own libs
using BioS_Gen

include("BioS_ProjsWFs_DataTypes.jl")
include("BioS_ProjsWFs_workflow_funs.jl")
include("BioS_ProjsWFs_arguments.jl")
include("BioS_ProjsWFs_run-commands.jl")
include("BioS_ProjsWFs_superproj.jl")

end # module BioS_ProjsandWorkflows
