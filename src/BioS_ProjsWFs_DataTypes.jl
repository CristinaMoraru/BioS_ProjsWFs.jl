export BioinfDT, BioinfProj, BioinfCmd, BioinfPipe, WorkflowStatus, BioinfSProj, BioinfMProj 
export BlastCmd, RunBlastCmds
export WrapCmd
export ProjReadMapping, ProjReadMapIndexing, ProjReadMapMapping, ProjReadMapIndexingMapping

# Abstract data types
abstract type BioinfDT end   #BioInf DataType

abstract type BioinfProj <:BioinfDT end
abstract type BioinfSProj <:BioinfProj end 
abstract type BioinfMProj <:BioinfProj end  

abstract type BioinfCmd <: BioinfDT end   #BioInf Simple command (one program)
abstract type BioinfPipe <: BioinfDT end  # Bioinf pipeline (several programs, no erros saved here yet)
abstract type BlastCmd <: BioinfCmd end
abstract type RunBlastCmds <: BlastCmd end   


abstract type ProjReadMapping <: BioinfProj end
abstract type ProjReadMapIndexing <: ProjReadMapping end
abstract type ProjReadMapMapping <: ProjReadMapping end
abstract type ProjReadMapIndexingMapping <: ProjReadMapping end


# General data structures
Base.@kwdef struct WrapCmd{T <: BioinfCmd} 
    cmd::T
    log_p::String
    err_p::String
    exit_p::String
    env::Union{Missing, String} = missing
    sbatch_maxtime::Union{String, Missing} = missing
    sbatch_cpuspertask::Union{Int64, Missing} = missing
    sbatch_mem::Union{String, Missing} = missing
end

# Data structures for managing the workflow
mutable struct WorkflowStatus
    signal::String    # do, use, ignore or remove
    progress::String  # not_done, running, finished, failed
end