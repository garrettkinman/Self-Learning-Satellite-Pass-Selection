# Copyright 2023 Garrett Kinman
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using Plots
using CairoMakie

## run simulations

include("simulator.jl")
include("energymodel.jl")

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

## plot λ tradeoffs

transmitters = [VirtualTransmitter(pref_model₂, ones(STATE_SIZE..., 5000)) for i ∈ 1:100];
λs = @pipe Vector(0.0:0.02:0.74) |> append!(_, Vector(0.75:0.01:0.85), Vector(0.855:0.005:1.0)) # want higher precision around 0.9 to 1.0

sim_results, times_to_tx = get_λ_tradeoffs(transmitters, λs=λs, noise_mode="BUCKET")

results_plt = Plots.scatter(λs, sim_results, label=false)
Plots.title!(results_plt, "Average TX Success Rate vs Discount Factor λ")
Plots.xlabel!(results_plt, "Discount Factor λ")
Plots.ylabel!(results_plt, "TX Success Rate")
Plots.xticks!(0.0:0.1:1.0)
Plots.savefig(results_plt, "lambda_success.png")

time_to_tx_plt = Plots.scatter(λs, times_to_tx, label=false)
Plots.title!(time_to_tx_plt, "Average Time to TX vs Discount Factor λ")
Plots.xlabel!(time_to_tx_plt, "Discount Factor λ")
Plots.ylabel!(time_to_tx_plt, "Mean Time to TX (hours)")
Plots.xticks!(0.0:0.1:1.0)
Plots.savefig(time_to_tx_plt, "lambda_time.png")

avg_powers = [power(1 / (24 * 3600), r, 0.5, 25 * 60) for r ∈ sim_results]
power_plt = Plots.scatter(λs, avg_powers, label=false)
Plots.title!(power_plt, "Average Modem Power vs Discount Factor λ")
Plots.xlabel!(power_plt, "Discount Factor λ")
Plots.ylabel!(power_plt, "Average Modem Power (W)")
Plots.xticks!(0.0:0.1:1.0)
Plots.savefig(power_plt, "lambda_power.png")

## energy model

r_attempt = LinRange(1, 48, 100) # 1 per hour to 1 per 48 hours
p_success = LinRange(0.01, 1, 100)
ϵ_pass = LinRange(0, 1, 2)
t_pass = LinRange(10, 60, 3) # 60 min to 10 min

fig = Figure(resolution = (1600, 2400), fontsize = 25)
for (i, ϵ) ∈ enumerate(ϵ_pass)
    for (j, t) ∈ enumerate(t_pass)
        ax = Axis3(fig[j, i], aspect=(1,1,1),
            title=L"\epsilon_{pass}=%$(ϵ), t_{pass}=%$(t) (min)",
            titlesize=40,
            perspectiveness=0.0,
            xlabel="Average time between attempts (hr)",
            ylabel="Probability of TX success",
            zlabel="Average power (W)",
            zlabeloffset=100,
            protrusions=50)
        P_avg = [power(1 / (f * 3600), r, ϵ, t * 60) for f ∈ r_attempt, r ∈ p_success]
        CairoMakie.surface!(ax, r_attempt, p_success, P_avg)
    end
end
Label(fig[0, :], "Average Power (W)", fontsize = 40)

fig

save("avg_power.png", fig)

# pref model 1
power(1 / (0.39*3600), 0.13, 0.5, 25*60) |> println
power(1 / (24*3600), 0.13, 0.5, 25*60) |> println
power(1 / (24*3600), 0.20, 0.5, 25*60) |> println

# pref model 2
power(1 / (1.26*3600), 0.42, 0.5, 25*60) |> println
power(1 / (23*3600), 0.42, 0.5, 25*60) |> println
power(1 / (23*3600), 0.57, 0.5, 25*60) |> println

# pref model 3
power(1 / (2.34*3600), 0.78, 0.5, 25*60) |> println
power(1 / (22*3600), 0.78, 0.5, 25*60) |> println
power(1 / (22*3600), 0.85, 0.5, 25*60) |> println