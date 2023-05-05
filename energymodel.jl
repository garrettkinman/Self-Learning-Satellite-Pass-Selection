using GLMakie
GLMakie.activate!()

using CairoMakie
CairoMakie.activate!()

const P_sl = 550e-6 # 550 μW
const P_gps = 230e-3 # 230 mW
const P_rx = 130e-3 # 130 mW
const E_tx = 12.24 # 12.24 J
const t_gps = 30 # 30 s
const r_pkt = 1 / 10_800 # 1 / 3 hr⁻¹ = 1 / 10,800 Hz

"Calculates E_attempt, the average total energy for an attempted transmission to satellite."
function energy(r_attempt, p_success, ϵ_pass, t_pass)
    E_success = (P_sl * (1 / r_attempt)) + (P_gps * t_gps) + (ϵ_pass * P_rx * t_pass) + (E_tx * (r_pkt / (p_success * r_attempt)))
    E_fail = (P_sl * (1 / r_attempt)) + (P_gps * t_gps) + (P_rx * t_pass)
    E_attempt = (p_success * E_success) + ((1 - p_success) * E_fail)

    return E_attempt
end

"Calculates P_avg, the average power consumption of the modem during operation."
function power(r_attempt, p_success, ϵ_pass, t_pass)
    t_elapsed = (1 / r_attempt) + t_gps + (p_success * ϵ_pass * t_pass) + ((1 - p_success) * t_pass)
    return energy(r_attempt, p_success, ϵ_pass, t_pass) / t_elapsed
end

r_attempt = LinRange(1, 48, 100) # 1 per hour to 1 per 48 hours
p_success = LinRange(0.01, 1, 100)
ϵ_pass = LinRange(0, 1, 2)
t_pass = LinRange(10, 60, 3) # 60 min to 10 min

fig = Figure(resolution = (1600, 2400), fontsize = 20)
for (i, ϵ) ∈ enumerate(ϵ_pass)
    for (j, t) ∈ enumerate(t_pass)
        ax = Axis3(fig[j, i], aspect=(1,1,1),
            title=L"\epsilon_{pass}=%$(ϵ), t_{pass}=%$(t) (min)",
            titlesize=30,
            perspectiveness=0.0,
            xlabel="Average time between attempts (hr)",
            ylabel="Probability of TX success",
            zlabel="Average power (W)",
            zlabeloffset=100)
        P_avg = [power(1 / (f * 3600), r, ϵ, t * 60) for f ∈ r_attempt, r ∈ p_success]
        surface!(ax, r_attempt, p_success, P_avg)
    end
end
Label(fig[0, :], "Average Power (W)", fontsize = 40)

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