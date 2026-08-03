local state = boop.runtime.ensureState()
state.trace.live = false
boop.runtime.resetVenomConfusionCount("package reload")
boop.resetShieldMode("package reload")
boop.attacks.clearTemporaryPreferences("package reload")

boop.bootstrap()
