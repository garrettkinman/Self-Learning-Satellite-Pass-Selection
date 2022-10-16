using NNlib
using Plots

"Convert continuous-valued state into discrete states using bucketing"
function discretize(angle::AbstractFloat, duration::AbstractFloat, noise::Integer)
    angle_bucket = 0
    duration_bucket = 0
    noise_bucket = 0

    if angle > 75.0
        angle_bucket = 5
    elseif angle > 60.0
        angle_bucket = 4
    elseif angle > 45.0
        angle_bucket = 3
    elseif angle > 30.0
        angle_bucket = 2
    else
        angle_bucket = 1
    end

    if duration > 50.0
        duration_bucket = 5
    elseif duration > 40.0
        duration_bucket = 4
    elseif duration > 30.0
        duration_bucket = 3
    elseif duration > 20.0
        duration_bucket = 2
    else
        duration_bucket = 1
    end
    
    if noise < -104
        noise_bucket = 5
    elseif noise < -101
        noise_bucket = 4
    elseif noise < -98
        noise_bucket = 3
    elseif noise < -95
        noise_bucket = 2
    else
        noise_bucket = 1
    end

    # use these as indices
    return (angle_bucket, duration_bucket, noise_bucket)
end

"Prefers high angles, long durations, and low noise"
function pref_model₁(angle::AbstractFloat, duration::AbstractFloat, noise::Integer)
    return σ(0.5 * (angle - 70.0)) * σ(0.5 * (duration - 35.0)) * σ(-(noise + 102))
end

"Prefers mid to high angles, mid to long durations, and mid to low noise"
function pref_model₂(angle::AbstractFloat, duration::AbstractFloat, noise::Integer)
    return σ(0.5 * (angle - 50.0)) * σ(0.5 * (duration - 20.0)) * σ(-(noise + 99))
end

"Prefers high angles, short durations, and low noise"
function pref_model₃(angle::AbstractFloat, duration::AbstractFloat, noise::Integer)
    return σ(0.5 * (angle - 70.0)) * σ(-0.5 * (duration - 20.0)) * σ(-(noise + 102))
end

"Represents an agent with a given preference model and current estimate of each state's value"
mutable struct VirtualTransmitter
    pref_model::Function
    value_estimates::AbstractArray{AbstractFloat,3} # should be 5×5×5 array, indexed as A×D×N
end