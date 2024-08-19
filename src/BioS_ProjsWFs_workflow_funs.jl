export ALLOWED_VALS_PROJ
export remove_prev, run_workflow 
export setsignal, setstep_primary!, setstep_intermediary!, setstep_final!, initialize_step, set2running!, set2finished! 
export ProjMultiWorkflow, initialize_workflow, do_wfstep
export load_proj, do_pd

"""
ALLOWED_VALS_PROJ is a constant dictionary which stores possible values related to the project management.

Signals for common, parallel steps (set by the user):
        * 'do' - run this predictor step. Can be always used, regardless of the signals in the previous steps
        * 'dont' - don't run this predictor step. It can be used only if the project is new (continue = false), or, for continued projects, if there was a 'dont' or 'remove' signal in the previous step.
        * 'use'- re-use predictor results calculated in previous runs of this project. It can't be used if the project is new (continue = false). For continued projects, it can be used only after 'do', 'use' or 'ignore' in the previous step, and, if their respective "progress" is finished.
        * 'use_external' - use results calculated previously by the predictor independently from a DoViP project.
        * 'ignore' - doesn't take into consideration existing results calculated in a previous run of this project. It can't be used if the project is new (continue = false). For continued projects, it can be used only after 'do', 'use' or 'ignore' in the previous step, and, if their respective "progress" is finished. 
        * 'remove' - removes results calculated in a previous step. It can't be used if the project is new (continue = false). For continued projects, it can be used only after 'do', 'use' or ignore in the previous step, regardless of their "progress". 
    
"""
const ALLOWED_VALS_PROJ = Dict(
    "signal" => ("do", "dont", "use", "ignore", "remove", "use_external"),   
    "progress" => ("not_done", "running", "finished", "failed"),
    "projtype" => ("singleworkflow", "multipleworkflow")
)

"""
    remove_prev
    This is a workflow management function.
"""

function remove_prev(args::Vector{String}, param::String, pd::String)
    rm_prev = extract_args(args, param, Bool, "true")
    if rm_prev == true
        rm_mkpaths([pd])
    end

    return nothing
end



function serialize_and_log(outp::String, proj::BioinfSProj, fun::Function)
    serialize("$(outp)/sproj_binary", proj)
    fun("$(outp)/project_parameters_and_status.txt", proj)

    return nothing
end

#region continue project
function load_proj(p::String, pd::String, inref::FnaP, sampleName::String)
    proj = deserialize(p)

    if inref != proj.inref
        println("
        The inref file is different from the one used in the previous run. Please check the input parameters.")
        exit()
    end

    if sampleName != proj.sampleName
        println("
        The sample (inref file) name is different from the one used in the previous run. Please check the input parameters.")
        exit()
    end

    if pd != proj.pd
        #println("
        #The project directory is different from the one used in the previous run. Please check the input parameters.")
        #exit()
        proj.pd = pd
    end


    return proj
end

#endregion continue project


#region workflow steps
function setsignal(newsignal::String, step::String; cont::Bool = false, oldsignal::Union{Missing, String} = missing, progress::Union{Missing, String} = missing)
    if newsignal in ["do", "use_external"]
        signal = newsignal
    
    elseif newsignal == "dont"
        if cont == false
            signal = newsignal
        else
            if oldsignal in ["dont", "remove"]
                signal = newsignal
            elseif oldsignal in ["do", "use", "ignore"]
                println("
                You can't change the signal for the '$(step)' step to 'dont', because the step was previously calculated. 
                If you don't want to consider the results from this step, set its signal to 'remove' or 'ignore'.")
                exit()
            elseif oldsignal in ["use_external"]
                println("
                You can't change the signal for the '$(step)' step to 'dont', because the step was previously calculated outside DoViP. 
                If you don't want to consider the results from this step, set its signal to 'ignore'.")
                exit()
            end
        end
    
    elseif newsignal == "ignore"
        if cont == false
            println("
            You can't set the signal for the '$(step)' step to 'ignore', because this is a new project and the step was NOT previously calculated. 
            If you don't want to calculate with the results for this step, set its signal to 'dont'.")
            exit()
        else
            if oldsignal in ["do", "use", "ignore", "use_external"]
                signal = newsignal
            elseif oldsignal in ["dont", "remove"]
                println("
                You can't change the signal for the '$(step)' step to 'ignore', because there are no previous results for this step. 
                If you don't want to consider the results from this step, set its signal to 'dont'.")
                exit()
            end
        end
    
    elseif newsignal == "remove"
        if cont == false
            println("
            You can't set the signal for the '$(step)' step to 'remove', because this is a new project and the step was NOT previously calculated. 
            If you don't want to calculate with the results for this step, set its signal to 'dont'.")
            exit()
        else
            if oldsignal in ["do", "use", "ignore"]
                signal = newsignal
            elseif oldsignal in ["dont", "remove"]
                println("
                You can't change the signal for the '$(step)' step to 'remove', because no previous results exist for this step. 
                If you don't want to consider the results from this step, set its signal to 'dont'.")
                exit()
            elseif  oldsignal in ["use_external"]
                println("
                You can't change the signal for the '$(step)' step to 'remove', because the previous results were calculated outside the DoViP pipeline. 
                If you don't want to consider the results from this step, set its signal to 'ignore'.")
                exit()
            end
        end
    
    elseif newsignal == "use" #considers the progress status from previous runs
        if cont == false
            println("
            You can't set the signal for the '$(step)' step to 'use', because this is a new project and the step was NOT previously calculated. 
            If you want to calculate the results for this step, set its signal to 'do'.")
            exit()
        else
            if oldsignal in ["do", "use", "ignore", "use_external"]
                if progress == "finished"
                    signal = newsignal
                else
                    println("
                    You can't change the signal for the '$(step)' step to 'use', because its progress status from the previous project run is 
                    '$(progress)', and thus, its results are incomplete. Kill the process if its still running, and then set the signal for this step to do.")
                    exit()
                end
            elseif oldsignal in ["dont", "remove"]
                println("
                You can't change the signal for the '$(step)' step to 'use', because no previous results exist for this step. 
                If you want to consider the results from this step, set its signal to 'do'.")
                exit()
            end
        end
    
    end

    return signal
 end

"""
setstep_primary!
    This is a workflow management function for when the project is continued. It is meant for steps in the begining of the workflow, on which other steps depend. 
        The user controls their signal and the user input in turn is controled by the setsignal function (see above).
"""
function setstep_primary!(bproj::BioinfSProj, step::String, dosteps::Dict{String, WorkflowStatus}, pd_own::Union{String, Missing}, pds2remove::Vector{String}; logfun::Union{Missing, Function} = missing) #where T <: Union{Missing, ProjMaxBin2, ProjMetaBat2, Projvamb, ProjMetaDecoder, ProjGenomad, ProjDVF, ProjvirSorter, ProjVibrant, ProjCheckV}
    if dosteps["$(step)"].signal in ["do", "use_external"]
        if ismissing(pd_own) == false 
            rm_path(pd_own)
        end
        rm_path(pds2remove)  
    
        if dosteps["$(step)"].progress in ["finished", "failed"]
            println("
            The current signal for the $(step) step is 'do' or 'use_external'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            The previous results of this step were removed, its status was set to 'not done' and it will be recalculated in this project run." )
            dosteps["$(step)"].progress = "not_done"
        elseif dosteps["$(step)"].progress in ["running"]
            println("
            The current signal for the $(step) step is 'do' or 'use_external'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            Therefore, this process is either still running or, more likely, it errored in a previous step. Its status was reset to 'not done' and its previous results were removed. 
            If its process is still running, kill it, and then start DoViP again.")
            dosteps["$(step)"].progress = "not_done"
            serialize("$(bproj.pd)/$(bproj.sampleName)/sproj.binary", bproj)
            if ismissing(logfun) == false
                logfun("$(bproj.pd)/$(bproj.sampleName)/project_parameters_and_status.txt", bproj)
            end
            exit()
        end

    elseif dosteps["$(step)"].signal in ["use", "ignore"]   
        rm_path(pds2remove) 
        # 'use' can only be set for projects which where previously "finished", ands thus there is no need to check its status
        # 'ignore' only removes the results from the dependent steps, but will do nothing on its own step, and thus there is no need to check its status.
         
    elseif dosteps["$(step)"].signal == "remove"

        if ismissing(pd_own) == false 
            rm_path(pd_own)
        end
        rm_path(pds2remove)
 
        if dosteps["$(step)"].progress in ["finished", "failed"]
            println("
            The current signal for the $(step) step is 'remove'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            The previous results of this step were removed, its status was set to 'not done'" )
            dosteps["$(step)"].progress = "not_done"
        elseif dosteps["$(step)"].progress in ["running"]
            println("
            The current signal for the $(step) step is 'remove'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            Therefore, this process is either still running or, more likely, it errored in a previous step. Its status was reset to 'not done' and its previous results were removed. 
            If its process is still running, kill it, and then start DoViP again.")
            dosteps["$(step)"].progress = "not_done"
            serialize("$(bproj.pd)/$(bproj.sampleName)/sproj.binary", bproj)
            if ismissing(logfun) == false
                logfun("$(bproj.pd)/$(bproj.sampleName)/project_parameters_and_status.txt", bproj)
            end
            exit()
        end
    end

    return dosteps
end

"""
    setstep_intermediary!
    This is a workflow management function for when the project is continued. It is meant for steps further in the workflow, on which other steps depend, 
        but the user has no control over their signal. Their signal is NOT controled by the setsignal function. Instead, their signal is programmed either to "do" or "use".
"""
function setstep_intermediary!(bproj::BioinfSProj, step::String, dosteps::Dict{String, WorkflowStatus}, pd_own::Union{String, Missing}, pds2remove_do::Vector{String}; 
                                pds2remove_use::Union{Vector{String}, Missing} = missing, logfun::Union{Missing, Function} = missing)

    if dosteps["$(step)"].signal == "use"
        if dosteps["$(step)"].progress in ["failed", "running", "not_done"]
            dosteps["$(step)"].signal = "do"
        elseif dosteps["$(step)"].progress in ["finished"]
            if ismissing(pds2remove_use) == false
                rm_path(pds2remove_use)
            end
            println("
            The current signal for the $(step) step was automaticaly set to 'use'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            Its results from a previous run will be used in the current run.")
        end
    end

    if dosteps["$(step)"].signal == "do"
        if ismissing(pd_own) == false 
            rm_path(pd_own)
        end
        rm_path(pds2remove_do)

        if dosteps["$(step)"].progress in ["not_done"]
            println("
            The current signal for the $(step) step was automaticaly set to 'do'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            This step will be calculated in this project run." )
        elseif dosteps["$(step)"].progress in ["finished", "failed"]
            println("
            The current signal for the $(step) step was automaticaly set to 'do'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            The previous results of this step were removed, its status was set to 'not done' and it will be recalculated in this project run." )
            dosteps["$(step)"].progress = "not_done"
        elseif dosteps["$(step)"].progress in ["running"]
            println("
            The current signal for the $(step) step is 'do'. Its status from a previous run was $(dosteps["$(step)"].progress). 
            Therefore, this process is either still running or, more likely, it errored in a previous step. Its status was reset to 'not done' and its previous results were removed. 
            If its process is still running, kill it, and then start DoViP again.")
            dosteps["$(step)"].progress = "not_done"
            serialize("$(bproj.pd)/$(bproj.sampleName)/sproj.binary", bproj)
            if ismissing(logfun) == false
                logfun("$(bproj.pd)/$(bproj.sampleName)/project_parameters_and_status.txt", bproj)
            end
            exit()
        end
        
    end

    return dosteps
end


"""
setstep_final!
    This is a workflow management function for when the project is continued. 
        It is for the last step in the workflow, from which no other step depends and the user has no control over its signal.
        Its signal will thus always be "do" (and it will not be controlled by the setsignal function).
"""
function setstep_final!(bproj::BioinfSProj, step::String, dosteps::Dict{String, WorkflowStatus}, pd::Union{String, Missing}; logfun::Union{Missing, Function} = missing)
    if dosteps["$(step)"].signal == "do"
        if ismissing(pd) == false 
            rm_path(pd)
        end

        if dosteps["$(step)"].progress in ["finished", "failed"]
            println("
            The $(step) step status in a previous run was $(dosteps["$(step)"].progress). Removing the step and recalculating it." )
            dosteps["$(step)"].progress = "not_done"
        elseif dosteps["$(step)"].progress in ["running"]
            dosteps["$(step)"].progress = "not_done"
            serialize("$(bproj.pd)/$(bproj.sampleName)/sproj.binary", bproj)
            if ismissing(logfun) == false
                logfun("$(bproj.pd)/$(bproj.sampleName)/project_parameters_and_status.txt", bproj)
            end
            println("
            The $(step) step is either still running or, more likely, it errored in a previous step. Its status was reset to 'not done' and its previous results were removed. 
            Kill the process first, if needed, and then run DoViP again.")
            exit()
        end
    end

    return dosteps
end

"""
    initialize_step
    This function creates the project object and folders for a given step in the workflow.
"""
function initialize_step(dosteps::Dict{String, WorkflowStatus}, step::String, fun::Function, splatargs, savedproj::Union{Missing, DataFrame, BioinfProj}, cont::Bool = false)
    if dosteps[step].signal == "do"
        projobj = fun(splatargs...)
    elseif dosteps[step].signal == "use_external"
        projobj = fun(splatargs...)
    elseif dosteps[step].signal == "use" && cont
        projobj = savedproj
    elseif dosteps[step].signal == "ignore" && cont
        projobj = savedproj
    else  #this is for the "remove" signal
        projobj = missing
    end

    return projobj
end

# set2running or set2finished functions for run_workflow methods
function set2running!(step::String, proj::BioinfSProj; logfun::Union{Missing, Function} = missing)

    proj.dosteps["$(step)"].progress = "running"
    serialize("$(proj.pd)/$(proj.sampleName)/sproj.binary", proj)
    if ismissing(logfun) == false
        logfun("$(proj.pd)/$(proj.sampleName)/project_parameters_and_status.txt", proj)
    end

    return nothing
end

function set2running!(step::Int64, proj::BioinfMProj)

    proj.dosteps[step].progress = "running"
    serialize("$(proj.spd)/mproj.binary", proj)

    return nothing
end

function set2finished!(step::String, proj::BioinfSProj; logfun::Union{Missing, Function} = missing)

    proj.dosteps["$(step)"].progress = "finished"
    serialize("$(proj.pd)/$(proj.sampleName)/sproj.binary", proj)
    if ismissing(logfun) == false
        logfun("$(proj.pd)/$(proj.sampleName)/project_parameters_and_status.txt", proj)
    end

    return nothing
end

function set2finished!(step::Int64, proj::BioinfMProj)

    proj.dosteps[step].progress = "finished"
    serialize("$(proj.spd)/mproj.binary", proj)

    return nothing
end


#
run_workflow(proj::Any) = println("run_workflow method not defined for this project type.")
run_workflow!(proj::Any) = println("run_workflow method not defined for this project type.")

function do_wfstep(step::String, proj::BioinfSProj, fun::Function, splatargs; logfun::Union{Missing, Function} = missing, splatkwargs...) # fun::Function
    if proj.dosteps[step].signal in ["do", "use_external"]
        set2running!(step, proj; logfun = logfun)

        res = fun(splatargs...; splatkwargs...) #fun(splatargs...))     

        set2finished!(step, proj; logfun = logfun)

        return res
    else
        return nothing
    end
end

"""
    This method is for functions which were performed in a previous run and now only used. It returns the previous results, if the workflow requires them. ????????????
"""
function do_wfstep(step::String, proj::BioinfSProj, fun::Function, splatargs, saved, ; logfun::Union{Missing, Function} = missing, splatkwargs...) # fun::Function
    if proj.dosteps[step].signal == "do"
        set2running!(step, proj; logfun = logfun)

        res = fun(splatargs...; splatkwargs...) #fun(splatargs...))     

        set2finished!(step, proj; logfun = logfun)

        return res
    elseif proj.dosteps[step].signal in ["use"]
        return saved
    else 
        return nothing
    end
end

#endregion

#region multiple workflow
struct ProjMultiWorkflow <: BioinfMProj
    projtype::String
    spd::String
    allrefs_params::DataFrame
    allSingleWorkflows::Vector{BioinfSProj}
    dosteps::Dict{Int64, WorkflowStatus}
 end

function do_pd(spd::String)
    if ispath(spd)
        println("The $spd folder already exists. Type 'yes' to overwrite it and continue. Type 'no' to quit DoViP.")
        answer = readline()

        if answer == "yes"
            rm_mkpaths([spd])
        elseif answer == "no"
            exit()
        else
            println("Invalid input, must be 'yes' or 'no'.")
            do_pd(spd)
        end
    end

    return nothing
end


 function ProjMultiWorkflow(args, fun::Function)
    spd = extract_args(args, "spd")

    cont = extract_args(args, "continue", Bool, "false")
    allrefs_params_p = extract_inFiles(args, "allrefs_params", BioS_Gen.ALLOWED_EXT["TableP"]) |> TableP
    allrefs_params_df = CSV.read(allrefs_params_p.p, DataFrame; delim='\t', header=1)

    if cont == false
        do_pd(spd)
        #allrefs_params_p = extract_inFiles(args, "allrefs_params", BioS_Gen.ALLOWED_EXT["TableP"]) |> TableP
        #allrefs_params_df = CSV.read(allrefs_params_p.p, DataFrame; delim='\t', header=1)
        allSingleWorkflows = Vector{Union{Missing, BioinfSProj}}(missing, nrow(allrefs_params_df))
        dosteps = Dict{Int64, WorkflowStatus}()

        colnames = names(allrefs_params_df)

        for row in 1:nrow(allrefs_params_df)
            args = Vector{String}(undef, ncol(allrefs_params_df))

            for col in eachindex(colnames)
                args[col] = "$(colnames[col])=$(allrefs_params_df[row, col])"
            end
            args = push!(args, "pd_prefix=$(spd)/")

            allSingleWorkflows[row] = fun(args)
            dosteps[row] = WorkflowStatus("do", "not_done")
        end

        mproj = ProjMultiWorkflow("multipleworkflow", spd, allrefs_params_df, allSingleWorkflows, dosteps)
        serialize("$(mproj.spd)/mproj.binary", mproj)
    else
        mproj = deserialize("$(spd)/mproj.binary")
        #allrefs_params_p = extract_inFiles(args, "allrefs_params", BioS_Gen.ALLOWED_EXT["TableP"]) |> TableP
        #allrefs_params_df = CSV.read(allrefs_params_p.p, DataFrame; delim='\t', header=1)

        colnames = names(allrefs_params_df)

        for i in eachindex(mproj.allSingleWorkflows)
            #if mproj.dosteps[i].progress in ["not_done", "running"]
            if "$(allrefs_params_df[i, :continue])" == "true" || mproj.dosteps[i].progress in ["not_done", "running"]
                println("
                ---------------------- Starting the SETUP of the DoViP workflow for input file $i -------------------------
                ")
                args = Vector{String}(undef, ncol(allrefs_params_df))
    
                for col in eachindex(colnames)
                    args[col] = "$(colnames[col])=$(allrefs_params_df[i, col])"
                end
                args = push!(args, "pd_prefix=$(spd)/")
    
                mproj.allSingleWorkflows[i] = fun(args)
                mproj.dosteps[i] = WorkflowStatus("do", "not_done")

                println("
                ---------------------- Finished the SETUP of the DoViP workflow for input file $i -------------------------
                ")
            else
                println("
                ---------------------- Skipping the setup of the DoViP workflow for input file $i, because its status in a previous run was $(mproj.dosteps[i].progress) -------------------------
                ")
            end
        end

        serialize("$(mproj.spd)/mproj.binary", mproj)

    end

    return mproj
 end
#endregion multiple workflow


"""
    initialize_workflow()
    It takes a  parameter of type ARGS and a function (the constructor for the single workflow project), and creates the project object.
    # Returns the project of the correct type.
"""

function initialize_workflow(args::Vector{String}, fun::Function)
    projtype = extract_args(args, "projtype", ALLOWED_VALS_PROJ["projtype"])

    if projtype == "singleworkflow"
        proj = fun(args)
    elseif projtype == "multipleworkflow"
        proj = ProjMultiWorkflow(args, fun)
    end

    return proj
end

