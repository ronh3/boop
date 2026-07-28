local state = boop.runtime.ensureState()
state.trace.live = false

boop.bootstrap()
