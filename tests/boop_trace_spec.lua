local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop trace gmcp events", function()
  before_each(function()
    helper.reset()
    boop.config.traceEnabled = true
  end)

  it("logs room info transitions and room item gmcp events", function()
    gmcp.Room.Info = {
      num = 15,
      area = "Test Area",
      exits = { n = 16, s = 14 },
    }

    boop.onRoomInfo()

    gmcp.Char.Items.List = {
      location = "room",
      items = {
        { id = "1", name = "a gold sovereign" },
        { id = "42", name = "a vicious gnoll soldier", attrib = "m" },
      },
    }
    boop.onRoomItemsList()

    gmcp.Char.Items.Add = {
      location = "room",
      item = { id = "2", name = "a small pile of sovereigns" },
    }
    boop.onRoomItemsAdd()

    gmcp.Char.Items.Remove = {
      location = "room",
      item = { id = "42", name = "a vicious gnoll soldier" },
    }
    boop.onRoomItemsRemove()

    local trace = table.concat(boop.state.traceBuffer or {}, "\n")
    assert.is_true(trace:find("gmcp room info: 1 -> 15 | area=Test Area | exits=2 | moved=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room items list: count=2 | gold=yes | gold=a gold sovereign (1)", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item add: a small pile of sovereigns (2) | gold=yes", 1, true) ~= nil)
    assert.is_true(trace:find("gmcp room item remove: a vicious gnoll soldier (42) | gold=no", 1, true) ~= nil)
  end)
end)
