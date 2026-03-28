boop.state = boop.state or {}

function boop.state.init()
  if boop.registry and boop.registry.attachUiConfigRegistries then
    boop.registry.attachUiConfigRegistries()
  end

  if boop.runtime and boop.runtime.ensureState then
    boop.runtime.ensureState()
    return
  end

  boop.state.hunting = boop.state.hunting or false
end
