if boop.stats and boop.stats.flushPersistence then
  boop.stats.flushPersistence("package reload")
end
local state = boop.runtime.ensureState()
boop.perf.setEnabled(false)
state.trace.live = false
boop.runtime.resetVenomConfusionCount("package reload")
boop.resetShieldMode("package reload")
boop.attacks.clearTemporaryPreferences("package reload")

boop.bootstrap()
