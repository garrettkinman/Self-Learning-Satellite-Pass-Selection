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

"Prefers low to high angles, short to long durations, and high to low noise"
function pref_model₃(angle::AbstractFloat, duration::AbstractFloat, noise::Integer)
    return σ(0.5 * (angle - 30.0)) * σ(0.5 * (duration - 10.0)) * σ(-(noise + 96))
end

"Represents an agent with a given preference model and current estimate of each state's value"
mutable struct VirtualTransmitter
    pref_model::Function
    value_estimates::AbstractArray{AbstractFloat,4} # should be 5×5×5×n array, indexed as A×D×N×E
end

const STATE_SIZE = 5, 5, 5

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

"Runs simulations for n epochs on a collection of transmitters with discount factor λ"
function simulate!(transmitters::AbstractVector{VirtualTransmitter}; n_epochs=1000, λ=0.9, noise_mode="CONSTANT")

    # use 100 satellite passes in 48 hours, which is roughly accurate to real life
    n_passes = 100

    # for storing tx success/failure results over the epochs
    # and time take to transmit
    results = zeros(length(transmitters), n_epochs)
    times_to_tx = zeros(length(transmitters), n_epochs)

    @withprogress for (i, txᵢ) ∈ enumerate(transmitters)
        # record how many times each state was visited
        s_counts = zeros(STATE_SIZE)

        for epochᵢ ∈ 1:n_epochs

            s̄ = []
            if noise_mode == "CONSTANT" # simulate using just one constant value for noise
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, -106) for j ∈ 1:n_passes]
            elseif noise_mode == "BUCKET" # simulate using random values from just one bucket
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-105)) for j ∈ 1:n_passes]
            elseif noise_mode == "RANDOM" # simulate using random values from all buckets
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-93)) for j ∈ 1:n_passes]
            end
            
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

            # record result and time to tx
            results[i, epochᵢ] = tx_result
            times_to_tx[i, epochᵢ] = t̄[selected_pass]

            # update estimates
            if epochᵢ != n_epochs
                # estimates should remain unchanged for all
                txᵢ.value_estimates[:, :, :, epochᵢ + 1] = txᵢ.value_estimates[:, :, :, epochᵢ]
                
                # except for the one pass selected
                vₙ = txᵢ.value_estimates[discretized_s..., epochᵢ] # current estimate
                vₙ₊₁ = vₙ + (1 / (s_counts[discretized_s...])) * (tx_result - vₙ) # new estimate
                txᵢ.value_estimates[discretized_s..., epochᵢ + 1] = vₙ₊₁
            end
        end

        @logprogress i / length(transmitters)
    end

    return results, times_to_tx
end

"Runs non-learning simulations for n epochs on a collection of transmitters"
function baseline(transmitters::AbstractVector{VirtualTransmitter}; n_epochs=1000, noise_mode="CONSTANT")

    # use 100 satellite passes in 48 hours, which is roughly accurate to real life
    n_passes = 100

    # for storing tx success/failure results over the epochs
    results = zeros(length(transmitters), n_epochs)

    @withprogress for (i, txᵢ) ∈ enumerate(transmitters)
        for epochᵢ ∈ 1:n_epochs
            
            s̄ = []
            if noise_mode == "CONSTANT" # simulate using just one constant value for noise
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, -106) for j ∈ 1:n_passes]
            elseif noise_mode == "BUCKET" # simulate using random values from just one bucket
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-105)) for j ∈ 1:n_passes]
            elseif noise_mode == "RANDOM" # simulate using random values from all buckets
                s̄ = [((75 * rand()) + 15, (50 * rand()) + 10, rand(-107:-93)) for j ∈ 1:n_passes]
            end

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

"Run simulations for a set of virtual transmitters for several values of discount factors, then plots out moving average and average time to TX"
function plot_sim_results(transmitters::AbstractVector{VirtualTransmitter}; n_epochs=5000, λs=[0.9,0.95,0.99], noise_mode="BUCKET")
    n_tx = length(transmitters)

    baseline_results = baseline(transmitters, n_epochs=n_epochs, noise_mode=noise_mode)
    
    # size of the moving window for moving averages
    window_size = 1000

    # create success rate plot
    results_plt = hline([baseline_results |> mean], label="baseline")
    title!(results_plt, "Moving Average TX Success Rate (window = $(window_size))")
    xlabel!(results_plt, "Epoch")
    ylabel!(results_plt, "TX Success Rate")

    # create average time to tx plot
    time_to_tx_plt = plot()
    title!(time_to_tx_plt, "Moving Average Time to TX (window = $(window_size))")
    xlabel!(time_to_tx_plt, "Epoch")
    ylabel!(time_to_tx_plt, "Mean Time to TX (hours)")

    for λᵢ ∈ λs
        sim_results, times_to_tx = simulate!(transmitters, n_epochs=n_epochs, λ=λᵢ, noise_mode=noise_mode)
        
        results_moving_avgs = zeros(n_epochs)
        times_moving_avgs = zeros(n_epochs)
        for i ∈ 1:n_epochs
            if i <= window_size
                results_moving_avgs[i] = sim_results[:, 1:i] |> mean
                times_moving_avgs[i] = times_to_tx[:, 1:i] |> mean
            else
                results_moving_avgs[i] = sim_results[:, (i-window_size):i] |> mean
                times_moving_avgs[i] = times_to_tx[:, (i-window_size):i] |> mean
            end
        end

        plot!(results_plt, results_moving_avgs, label="λ = $(λᵢ)")
        plot!(time_to_tx_plt, times_moving_avgs, label="λ = $(λᵢ)")
    end

    return plot(results_plt, time_to_tx_plt, layout = (2, 1))
end

# construct and simulate 100 virtual transmitters for each preference model
# optimistic initialization (i.e., the value function approximator begins as all ones)
transmitters₁ = [VirtualTransmitter(pref_model₁, ones(STATE_SIZE..., 5000)) for i ∈ 1:100];
bkt_plt₁ = plot_sim_results(transmitters₁, noise_mode="BUCKET")
savefig(bkt_plt₁, "bkt_noise_pref_model1.png")
rand_plt₁ = plot_sim_results(transmitters₁, noise_mode="RANDOM")
savefig(rand_plt₁, "rand_noise_pref_model1.png")

transmitters₂ = [VirtualTransmitter(pref_model₂, ones(STATE_SIZE..., 5000)) for i ∈ 1:100];
bkt_plt₂ = plot_sim_results(transmitters₂, noise_mode="BUCKET")
savefig(bkt_plt₂, "bkt_noise_pref_model2.png")
rand_plt₂ = plot_sim_results(transmitters₂, noise_mode="RANDOM")
savefig(rand_plt₂, "rand_noise_pref_model2.png")

transmitters₃ = [VirtualTransmitter(pref_model₃, ones(STATE_SIZE..., 5000)) for i ∈ 1:100];
bkt_plt₃ = plot_sim_results(transmitters₃, noise_mode="BUCKET")
savefig(bkt_plt₃, "bkt_noise_pref_model3.png")
rand_plt₃ = plot_sim_results(transmitters₃, noise_mode="RANDOM")
savefig(rand_plt₃, "rand_noise_pref_model3.png")

# construct and simulate 100 virtual transmitters for preference model 2
# optimistic initialization (i.e., the value function approximator begins as all ones)
"Run simulations for a set of virtual transmitters for several values of discount factors, then plot out moving average vs discount factor λ"
function plot_λ_tradeoffs(transmitters::AbstractVector{VirtualTransmitter}; n_epochs=5000, λs=0.0:0.01:1.0, noise_mode="BUCKET")
    n_tx = length(transmitters)

    # size of the moving window for moving averages
    window_size = 1000

    stable_sim_results = []
    stable_times_to_tx = []
    for λᵢ ∈ λs
        @info "Simulating λ = $(λᵢ)..."
        
        sim_results, times_to_tx = simulate!(transmitters, n_epochs=n_epochs, λ=λᵢ, noise_mode=noise_mode)
            
        results_moving_avgs = zeros(n_epochs)
        times_moving_avgs = zeros(n_epochs)
        for i ∈ 1:n_epochs
            if i <= window_size
                results_moving_avgs[i] = sim_results[:, 1:i] |> mean
                times_moving_avgs[i] = times_to_tx[:, 1:i] |> mean
            else
                results_moving_avgs[i] = sim_results[:, (i-window_size):i] |> mean
                times_moving_avgs[i] = times_to_tx[:, (i-window_size):i] |> mean
            end
        end

        # record the last moving average of the sim results and time to tx, as this represents a fairly "stable" view 
        push!(stable_sim_results, results_moving_avgs[end])
        push!(stable_times_to_tx, times_moving_avgs[end])
    end

    results_plt = scatter(λs, stable_sim_results, label=false)
    title!(results_plt, "Average TX Success Rate vs Discount Factor λ")
    xlabel!(results_plt, "Discount Factor λ")
    ylabel!(results_plt, "TX Success Rate")
    xticks!(0.0:0.05:1.0)

    time_to_tx_plt = scatter(λs, stable_times_to_tx, label=false)
    title!(time_to_tx_plt, "Average Time to TX vs Discount Factor λ")
    xlabel!(time_to_tx_plt, "Discount Factor λ")
    ylabel!(time_to_tx_plt, "Mean Time to TX (hours)")
    xticks!(0.0:0.05:1.0)

    return results_plt, time_to_tx_plt
end

transmitters = [VirtualTransmitter(pref_model₂, ones(STATE_SIZE..., 5000)) for i ∈ 1:100];
λs = @pipe Vector(0.0:0.02:0.74) |> append!(_, Vector(0.75:0.01:0.85), Vector(0.855:0.005:1.0)) # want higher precision around 0.9 to 1.0
results_plt, time_to_tx_plt = plot_λ_tradeoffs(transmitters, λs=λs, noise_mode="BUCKET")

results_plt
time_to_tx_plt

combined_plt = plot(results_plt, time_to_tx_plt, layout = (2, 1))
savefig(combined_plt, "lambda_tradeoffs.png")
