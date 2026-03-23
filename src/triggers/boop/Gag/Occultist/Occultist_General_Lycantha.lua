-- Observed Occultist Lycantha hound-attack line.
boop.gag.onAttackLine({
  source = "Occultist/General/Lycantha.lua",
  ability = "Lycantha",
  actor = { kind = "literal", value = "You" },
  target = { kind = "match", index = 2 },
}, matches, line or "")
