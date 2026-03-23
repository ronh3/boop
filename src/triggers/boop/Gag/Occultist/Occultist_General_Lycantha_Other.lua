-- Observed third-person Occultist Lycantha hound-attack line.
boop.gag.onAttackLine({
  source = "Occultist/General/Lycantha_Other.lua",
  ability = "Lycantha",
  actor = { kind = "literal", value = "Chaos Hound" },
  target = { kind = "match", index = 2 },
}, matches, line or "")
