# Self-Learning-Satellite-Pass-Selection
Simulation of a self-learning satellite pass selection algorithm as part of my master's thesis.

The algorithm is designed to allow individual sensors to learn from experience with satellite transmission successes and failures to quantify what makes a "good" satellite pass for each site, so the devices can spend their limited battery power on more likely-to-succeed transmission attempts.

The algorithm is basically a combination of Monte Carlo learning (from regular reinforcement learning) and softmax exploration (from the k-armed bandit problem).
