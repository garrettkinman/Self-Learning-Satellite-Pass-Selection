using GLMakie
GLMakie.activate!()

using CairoMakie
CairoMakie.activate!()

"Calculates E_attempt, the average total energy for an attempted transmission to satellite."
function energy(f_attempt, r_success, ϵ_pass, t_pass)
    P_sl = 550e-6 # 550 μW
    P_gps = 230e-3 # 230 mW
    P_rx = 130e-3 # 130 mW
    E_tx = 12.24 # 12.24 J
    t_gps = 30 # 30 s
    f_pkt = 1 / 10_800 # 1 / 3 hr⁻¹ = 1 / 10,800 Hz

    E_success = (P_sl * (1 / f_attempt)) + (P_gps * t_gps) + (ϵ_pass * P_rx * t_pass) + (E_tx * (f_pkt / (r_success * f_attempt)))
    E_fail = (P_sl * (1 / f_attempt)) + (P_gps * t_gps) + (P_rx * t_pass)
    E_attempt = (r_success * E_success) + ((1 - r_success) * E_fail)

    return E_attempt
end

"Calculates P_avg, the average power consumption of the modem during operation."
function power(f_attempt, r_success, ϵ_pass, t_pass)
    return energy(f_attempt, r_success, ϵ_pass, t_pass) * f_attempt
end

f_attempt = LinRange(1 / 3_600, 1 / 172_800, 100) # 1 per hour to 1 per 48 hours
r_success = LinRange(0.0, 1.0, 100)
ϵ_pass = LinRange(1.0, 0.0, 2)
t_pass = LinRange(3600.0, 600.0, 3) # 60 min to 10 min

fig = Figure(resolution = (1600, 2400), fontsize = 14)
for (i, ϵ) ∈ enumerate(ϵ_pass)
    for (j, t) ∈ enumerate(t_pass)
        # TODO: latex-ify
        ax = Axis3(fig[j, i], aspect=(1,1,1),
            title="ϵ_pass = $(ϵ)\nt_pass = $(t)",
            perspectiveness=0.0,
            xlabel="f_attempt",
            ylabel="r_success",
            zlabel="P_avg")
        P_avg = [power(f, r, ϵ, t) for f ∈ f_attempt, r ∈ r_success]
        surface!(ax, f_attempt, r_success, P_avg)
    end
end