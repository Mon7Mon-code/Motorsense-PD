import numpy as np
import matplotlib.pyplot as plt

# -------------------------
# Raw Data
# -------------------------
load = np.array([0,1,2,3,4,5,6,7,8,9])  # N
deflection = np.array([0.00,0.46,0.96,1.46,1.91,2.39,2.89,3.31,3.81,4.28])  # mm

# -------------------------
# Linear Regression
# -------------------------
slope, intercept = np.polyfit(load, deflection, 1)
fit = slope * load + intercept

# R^2 calculation
r = np.corrcoef(load, deflection)[0,1]
r_squared = r**2

# -------------------------
# Plot
# -------------------------
plt.figure()
plt.scatter(load, deflection)
plt.plot(load, fit)

plt.xlabel("Load (N)")
plt.ylabel("Deflection (mm)")
plt.title("Load vs Deflection")
plt.grid(True)

# Display equation on graph
plt.text(0.5, max(deflection)*0.8,
         f"y = {slope:.4f}x + {intercept:.4f}\nR² = {r_squared:.5f}")

plt.show()

# -------------------------
# Print Key Values
# -------------------------
print("Gradient (Compliance) =", round(slope,4), "mm/N")
print("Stiffness =", round(1/slope,4), "N/mm")
print("R² =", round(r_squared,5))import numpy as np
import matplotlib.pyplot as plt

# -------------------------
# Raw Data
# -------------------------
load = np.array([0,1,2,3,4,5,6,7,8,9])  # N
deflection = np.array([0.00,0.46,0.96,1.46,1.91,2.39,2.89,3.31,3.81,4.28])  # mm

# -------------------------
# Linear Regression
# -------------------------
slope, intercept = np.polyfit(load, deflection, 1)
fit = slope * load + intercept

# R^2 calculation
r = np.corrcoef(load, deflection)[0,1]
r_squared = r**2

# -------------------------
# Plot
# -------------------------
plt.figure()
plt.scatter(load, deflection)
plt.plot(load, fit)

plt.xlabel("Load (N)")
plt.ylabel("Deflection (mm)")
plt.title("Load vs Deflection")
plt.grid(True)

# Display equation on graph
plt.text(0.5, max(deflection)*0.8,
         f"y = {slope:.4f}x + {intercept:.4f}\nR² = {r_squared:.5f}")

plt.show()

# -------------------------
# Print Key Values
# -------------------------
print("Gradient (Compliance) =", round(slope,4), "mm/N")
print("Stiffness =", round(1/slope,4), "N/mm")
print("R² =", round(r_squared,5))
