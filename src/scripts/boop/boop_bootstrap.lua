local state = boop.runtime.ensureState()
state.trace.live = false
boop.resetShieldMode("package reload")

boop.bootstrap()
