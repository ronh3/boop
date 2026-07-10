boop = boop or {}
boop.attacks = boop.attacks or {}
boop.attacks.registry = boop.attacks.registry or {}
boop.attacks.pendingRegistry = boop.attacks.pendingRegistry or {}

if type(boop.attacks.register) ~= "function" then
  function boop.attacks.register(class, profile)
    if not class or class == "" then return end
    boop.attacks.pendingRegistry[#boop.attacks.pendingRegistry + 1] = {
      class = class,
      profile = profile or {},
    }
  end
end
