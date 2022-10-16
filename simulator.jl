using NNlib
using Plots
using Logging
using ProgressLogging
using StatsBase


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
    value_estimates::AbstractArray{AbstractFloat,4} # should be 5×5×5×n array, indexed as A×D×N×E
end

const STATE_SIZE = 5, 5, 5

"Runs simulations for n epochs on a collection of transmitters with discount factor λ"
function simulate!(transmitters::AbstractVector{VirtualTransmitter}, n_epochs=1000, λ=0.9)
    @info "Beginning simulation!"

    # use 100 satellite passes in 48 hours, which is roughly accurate to real life
    n_passes = 100

    # for storing tx success/failure results over the epochs
    results = zeros(length(transmitters), n_epochs)

    @withprogress for (i, txᵢ) ∈ enumerate(transmitters)
        # record how many times each state was visited
        s_counts = zeros(STATE_SIZE)

        for epochᵢ ∈ 1:n_epochs
            # TODO: choose just one value for noise each epoch?
            # s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-93)) for j ∈ 1:n_passes]
            s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, -106) for j ∈ 1:n_passes]
            t̄ = rand(n_passes) .* 48
            v̄ = [txᵢ.value_estimates[discretize(sᵢ...)..., epochᵢ] for sᵢ ∈ s̄] # corresponding value estimates for each discretized pass

            # calculate all the probabilities according to the policy π
            probabilities = (λ .^ (t̄)) .* v̄ |> softmax

            # randomly select a pass, weighted according to the policy π
            selected_pass = sample(1:n_passes, Weights(probabilities))

            # now that a pass is selected, store its indices into the value approximator
            # and update state visit count
            discretized_s = discretize(s̄[selected_pass]...)
            s_counts[discretized_s...] += 1.0

            # simulate tx for the selected pass
            tx_result = (rand() < txᵢ.pref_model(s̄[selected_pass]...)) * 1.0

            results[i, epochᵢ] = tx_result

            # update estimates
            if epochᵢ != n_epochs
                # estimates should remain unchanged for all
                txᵢ.value_estimates[:, :, :, epochᵢ + 1] = txᵢ.value_estimates[:, :, :, epochᵢ]
                
                # except for the one pass selected
                vₙ = txᵢ.value_estimates[discretized_s..., epochᵢ] # current estimate
                vₙ₊₁ = vₙ + (1 / (s_counts[discretized_s...] + 1)) * (tx_result - vₙ) # new estimate
                txᵢ.value_estimates[discretized_s..., epochᵢ + 1] = vₙ₊₁
            end
        end

        @logprogress i / length(transmitters)
    end

    return results
end

"Runs non-learning simulations for n epochs on a collection of transmitters"
function baseline(transmitters::AbstractVector{VirtualTransmitter}, n_epochs=1000)
    @info "Beginning simulation!"

    # use 100 satellite passes in 48 hours, which is roughly accurate to real life
    n_passes = 100

    # for storing tx success/failure results over the epochs
    results = zeros(length(transmitters), n_epochs)

    @withprogress for (i, txᵢ) ∈ enumerate(transmitters)
        for epochᵢ ∈ 1:n_epochs
            # TODO: choose just one value for noise each epoch?
            # s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-93)) for j ∈ 1:n_passes]
            s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, -106) for j ∈ 1:n_passes]

            # randomly select a pass, weighted evenly
            selected_pass = rand(1:n_passes)

            # simulate tx for the selected pass
            tx_result = (rand() < txᵢ.pref_model(s̄[selected_pass]...)) * 1.0

            results[i, epochᵢ] = tx_result
        end

        @logprogress i / length(transmitters)
    end

    return results
end

# construct 100 virtual transmitters with the first preference model
# optimistic initialization (i.e., the value function approximator begins as all ones)
transmitters₁ = [VirtualTransmitter(pref_model₁, ones(STATE_SIZE..., 10000)) for i ∈ 1:100];

results₁ = simulate!(transmitters₁, 10000, 0.99)
baseline_results₁ = baseline(transmitters₁, 10000)

results₁ |> mean
results₁[:,1:1000] |> mean
results₁[:,9000:10000] |> mean

baseline_results₁ |> mean
baseline_results₁[:,1:1000] |> mean
baseline_results₁[:,9000:10000] |> mean

transmitters₁[1].value_estimates[:,:,:,10000]

transmitters₂ = [VirtualTransmitter(pref_model₂, ones(STATE_SIZE..., 10000)) for i ∈ 1:100];
results₂ = simulate!(transmitters₂, 10000, 0.99)
baseline_results₂ = baseline(transmitters₂, 10000)

results₂ |> mean
results₂[:,1:1000] |> mean
results₂[:,9000:10000] |> mean

baseline_results₂ |> mean
baseline_results₂[:,1:1000] |> mean
baseline_results₂[:,9000:10000] |> mean

transmitters₂[1].value_estimates[:,:,:,10000]