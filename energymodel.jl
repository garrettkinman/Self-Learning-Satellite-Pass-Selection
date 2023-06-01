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