local state = boop.runtime.ensureState()
state.trace.live = false
boop.resetShieldMode("package reload")
boop.attacks.clearTemporaryPreferences("package reload")

boop.bootstrap()
