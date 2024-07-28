export gatherOutputs

function gatherOutputs(pd::String, output::String, gatherDir::String)
    prefix = basename(pd)
    sufix = basename(output)
    newP = "$gatherDir/$(prefix)_$(sufix)"

    cp(output, newP)

    return nothing
end