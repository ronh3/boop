boop.state = boop.state or {}

function boop.state.init()
  if boop.registry and boop.registry.attachUiConfigRegistries then
    boop.registry.attachUiConfigRegistries()
  end

  if boop.runtime and boop.runtime.ensureState then
    boop.state = boop.runtime.ensureState()
    return
  end

  boop.state = boop.state or { combat = {} }
  boop.state.combat = boop.state.combat or {}
  boop.state.combat.hunting = boop.state.combat.hunting or false
end
