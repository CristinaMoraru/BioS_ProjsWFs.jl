export build_cmd, do_cmd, do_pipe
export build_string_cmd, do_string_cmd

# Functions to build the commands, return a Cmd data type.
function build_cmd(cmd::T) where T <: BioinfCmd
    println("Unknown command: $cmd")
end

function build_cmd(cmd::T, parentD::String) where T <: BioinfCmd
    println("Unknown command: $cmd")
end

function build_string_cmd(cmd::T) where T <: BioinfCmd
    println("Unknown command: $cmd")
end

function extract_sbatch_jobid(output::String)
# Extract job ID from output
    job_id_match = match(r"Submitted batch job (\d+)", output)

    if job_id_match !== nothing
        job_id = job_id_match[1]
        println("Job ID: ", job_id)
    else
        println("Failed to submit job or extract Job ID.")
    end

    return job_id_match
end

function wait_for_job_completion(job_id::String)
    # Define the command to check job status using sacct
    sacct_cmd = `sacct -j $job_id --format=State --noheader`
    
    # Loop until the job status is either COMPLETED, FAILED, or CANCELLED
    while true
        # Execute sacct command and capture the output
        output = strip(String(read(pipeline(sacct_cmd, stdout=Pipe()), String)))
        
        # Check if the job has completed, failed, or was cancelled
        if occursin("COMPLETED", output)
            println("Job $job_id completed successfully.")
            status = "completed"
            break  # Exit the loop
        elseif occursin("FAILED", output) || occursin("CANCELLED", output)
            println("Job $job_id failed or was cancelled.")
            status = "failed"
            break  # Exit the loop
        else
            #println("Job $job_id is still running or in a pending state. Checking again in 10 seconds.")
            sleep(10)  # Wait for 10 seconds before checking again
        end
    end

    return status
end

function do_cmd(obj::WrapCmd{T}, program::String, env::Bool, parentD::String; sbatch::Bool = false) where T <: BioinfCmd
    println("Running $(program).")
    
    if env == true
        cmd = `conda run -n $(obj.env) $(build_cmd(obj.cmd, parentD))`
    else
        cmd = build_cmd(obj.cmd, parentD)
    end

    

    if sbatch == true
        sbatch_command = `sbatch --job-name=$(program) --output=$parentD/$(obj.log_p)_%.j --error=$(parentD)/$(obj.err_p)_%.j --time=$(obj.sbatch_maxtime) --cpus-per-task=$(obj.sbatch_cpuspertask) --mem=$(obj.sbatch_mem) --wrap="$(cmd)"`
        println(sbatch_command)
        output = read(open(sbatch_command), String)

        job_id = extract_sbatch_jobid(output)
        job_status = wait_for_job_completion(job_id)
        if job_status == "completed"
            println("$(program) finished successfully.")
        else
            error("$(program) calculation failed.")
        end
        
    else
        println(cmd)
        status = run(pipeline(cmd; stdout = "$parentD/$(obj.log_p)", stderr = "$(parentD)/$(obj.err_p)"))  #check what type is that and define it here
        write_error(status.exitcode, "$parentD/$(obj.exit_p)")

        if status.exitcode == 0
            println("$(program) finished successfully.")
        else
            error("$(program) calculation failed.")
        end
    end

    return nothing
end

function do_cmd(obj::WrapCmd{T}, program::String, env::Bool) where T <: BioinfCmd
    println("Running $(program).")
    
    if env == true
        cmd = `conda run -n $(obj.env) $(build_cmd(obj.cmd))`
    else
        cmd = build_cmd(obj.cmd)
    end

    println(cmd)

    status = run(pipeline(cmd; stdout = obj.log_p, stderr = obj.err_p))  #check what type is that and define it here
    write_error(status.exitcode, obj.exit_p)

    if status.exitcode == 0
        println("$(program) finished successfully.")
    else
        error("$(program) calculation failed.")
    end

    return nothing
end

function do_string_cmd(obj::WrapCmd{T}, program::String, env::Bool) where T <: BioinfCmd
    println("Running $(program).")
    
    cmd_str = build_string_cmd(obj.cmd)

    if env == true
        cmd_str = "conda run -n $(obj.env) $(cmd_str)"
        println("$(cmd_str)")
    end

    cmd = `bash -c $cmd_str`
    println(cmd)

    status = run(pipeline(cmd; stdout = obj.log_p, stderr = obj.err_p))  #check what type is that and define it here
    write_error(status.exitcode, obj.exit_p)

    if status.exitcode == 0
        println("$(program) finished successfully.")
    else
        error("$(program) calculation failed.")
    end

    return nothing
end

function do_pipe(obj::BioinfPipe, program::String)
    println("Running $(program).")
    
    pipe = build_pipe(obj)
    status = run(pipe)

    if status.exitcode == 0
        println("$(program) finished successfully.")
    else
        error("$(program) calculation failed.")
    end

    return nothing
end