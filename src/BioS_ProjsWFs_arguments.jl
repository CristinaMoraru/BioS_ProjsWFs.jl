export simple_extract_args, extract_args, extract_inPaths, extract_inFiles, extract_inDir_byExt, checkRange, extract_range_args
export extract_default_args, extract_multiple_args


"""
    ErrsMandParams is a datatype storying error messages produced when the parameters of the program are inputed incorrectly.
"""
struct ErrsMandParams
    no_params::String
    many_params::String
    not_allowed::String
end

function ErrsMandParams(program::String, param::String; val::String = "")
    no_params = "
                Aborting $program because the mandatory parameter '$param' is missing. Please make sure you input it correctly and try again.
                "
    many_params = "
                Aborting $program because the mandatory parameter '$param' was inputed more times. Please make sure you input it correctly and try again.
                "
    not_allowed = "
                    Aborting $program because the value '$val' of the '$param' parameter is not valid. Please make sure you input it correctly and try again.
                    "
    return ErrsMandParams(no_params, many_params, not_allowed)
end


### extract parameter values from ARGS object

"""

"""
function simple_extract_args(args::Vector{String}, param::String)
    indices = findall(x -> occursin(Regex("^$(param)="), x), args)

    errors = ErrsMandParams("Program", param)

    if length(indices) == 0
        println(errors.no_params)
        exit()
    elseif length(indices) >= 2
        println(errors.many_params)
        exit()
    else  
        val = replace(args[indices[1]], Regex("^$(param)=") => "")
        errors = ErrsMandParams("Program", param; val = val)
    end

    return val, errors
end


function extract_multiple_args(args::Vector{String}, param::String)
    indices = findall(x -> occursin(Regex("^$(param)\\d+="), x), args)
    val_vec = fill("", length(indices))
    errors = ErrsMandParams("Program", param)

    if length(indices) == 0
        println(errors.no_params)
        exit()
    else  
        for i in eachindex(indices)
            val_vec[i] = replace(args[indices[i]], Regex("^$(param)\\d+=") => "")
        end
    end

    return val_vec
end

"""
    checkRange(min::Int64, max::Int64)
    I'm using this function to check if the minimum and maximum values of a UnitRange type parameter are inputed correctly.
"""
function checkRange(min::Int64, max::Int64)
    if min > max
        println("
                The minimum value cannot be larger than the maximum value. Please check your input and try again.
                ")
        exit()
    end
end

"""
    extract_args
    It extracts different arguments and their values from the ARGS variable. 
    This method is for mandatory parameters with allowed values, e.g projtype. It will abort if no param is given by the user.
"""
function extract_args(args::Vector{String}, param::String, allowed)#::Dict(String, Tuple))
    val, errors = simple_extract_args(args, param)

    if ispresent(val, allowed) == true
        return val
    else
        println(errors.not_allowed)
        println("Allowed values are '$(allowed)'.")
        exit()
    end
   
end


"""
    extract_args
    It extracts different arguments and their values from the ARGS variable. 
    This method is for mandatory parameters, e.g projdir, input, output. It will abort if no param is given by the user.
"""
function extract_args(args::Vector{String}, param::String)::String
    val, errors = simple_extract_args(args, param)

    return val
end


"""
    extract_inPaths
    It extracts the input path from the ARGS variable and it checks if the input path exists. 
        If it doesn't, the program will abort.
"""
function extract_inPaths(args::Vector{String}, param::String)::String
    val, errors = simple_extract_args(args, param)

    if !ispath(val)
        println("
                The path '$val' does not exist. Please check your input and try again.
                ")
        exit()
    end

    return val
end


"""
    extract_inFiles
    It extracts the input file from the ARGS variable, it checks if it has the allowed extention
     and it checks if it exists. 
        If one the conditions are not meet, the program will abort.
"""
function extract_inFiles(args::Vector{String}, param::String, allowed)::String
    val, errors = simple_extract_args(args, param)
  
    ext = getFileExtention(val)

    if !ispresent(ext, allowed)
        println(errors.not_allowed)
        exit()
    end

    if !isfile(val)
        println("
                The path '$val' does not exist. Please check your input and try again.
                ")
        exit()
    end

    return val
end


"""
    extract_inDir_byExt
    This method takes as input an args vector path and returns only those files that have the allowed extension. 
    ## Returns:
    The ouput is a vector of the given PathsDT type
"""	

function extract_inDir_byExt(args::Vector{String}, param::String, allowed, T::DataType)
    inDir = extract_inPaths(args, param)
    inFilesP = dir_cont(inDir, allowed, T)

    return inFilesP
end

"""
    extract_default_args
    Method to extract default parameters from an ARGS variable.
"""
function extract_default_args(args::Vector{String}, param::String, default::Union{AbstractFloat, Integer, Bool, String})
    indices = findall(x -> occursin(Regex("^$(param)="), x), args)

    if length(indices) == 0
        return string(default)
    elseif length(indices) >= 2
        println("
                The '$param' parameter was inputed twice. Continuing calculations with the default value, which is $default.
                ")
        return string(default)
    else  
        val = replace(args[indices[1]], Regex("^$(param)=") => "")
    end

    return val
end


"""
    extract_args
    Method to extract numerical parameters from an ARGS variable.
"""
function extract_args(args::Vector{String}, param::String, type::DataType, default::Union{AbstractFloat, Integer}, 
                    min::Union{AbstractFloat, Integer}, max::Union{AbstractFloat, Integer})
    
    val = extract_default_args(args, param, default)
    val = parse(type, val)

    if val >= min && val <= max
        return val
    else
        println("
                The value of the '$param' parameter is outside the accepted range (minimum = $min, max = $max). 
                Continuing calculations with the default value for the '$param', which is $default.
                ")
        return default
    end
  
end

"""
    extract_args
    Method to extract Boolean parameters from an ARGS variable.
"""
function extract_args(args::Vector{String}, param::String, type::DataType, default::String) 
    if type != Bool
        println("
                The type of the '$param' parameter is not boolean. It needs to be either true or false. Exiting function.
                ")
        exit()
    end

    val = extract_default_args(args, param, default)

    if val != "false" && val != "true"
        println("
                The value $val of the '$param' parameter is not boolean. It needs to be either true or false. Exiting function.
                ")
        exit()
    end

    val = parse(type, val)

    return val
end


"""
    extract_args
    Method to extract string parameters with default options and allowed values from an ARGS variable.
""" 
function extract_args(args::Vector{String}, param::String, default::String; allowed) 

    val = extract_default_args(args, param, default)
    
    if ispresent(val, allowed) == true
        return val
    else
        println("
                The value of the '$param' parameter is not allowed. Continuing calculations with the default value for the '$param' parameter, which is $default.
                ")
        return default
    end

end



function extract_range_args(args::Vector{String}, param_min::String, param_max::String, type::DataType, default_min::Union{AbstractFloat, Integer}, 
    default_max::Union{AbstractFloat, Integer}, min::Union{AbstractFloat, Integer}, max::Union{AbstractFloat, Integer})
    
    minRange = extract_args(args, param_min, type, default_min, min, max)
    maxRange = extract_args(args, param_max, type, default_max, min, max)
    checkRange(minRange, maxRange)

    return minRange:maxRange
end




