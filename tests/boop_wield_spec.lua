local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop wield tracking", function()
  before_each(function()
    helper.reset()
  end)

  it("tracks left and right wielded items from the inventory list attrib flags", function()
    gmcp.Char.Items.List = {
      location = "inv",
      items = {
        { id = "11", name = "a curved blade of broken chains", icon = "weapon", attrib = "L" },
        { id = "12", name = "a broad-bladed sword of hardship", icon = "weapon", attrib = "l" },
        { id = "13", name = "a shield of tests", icon = "armour", attrib = "" },
      },
    }

    boop.onRoomItemsList()

    assert.are.equal("a broad-bladed sword of hardship", boop.state.inventory.wieldedLeft.name)
    assert.are.equal("12", boop.state.inventory.wieldedLeft.id)
    assert.are.equal("a curved blade of broken chains", boop.state.inventory.wieldedRight.name)
    assert.are.equal("11", boop.state.inventory.wieldedRight.id)
  end)

  it("updates and clears tracked wielded items from inventory update and remove events", function()
    gmcp.Char.Items.List = {
      location = "inv",
      items = {
        { id = "11", name = "a curved blade of broken chains", icon = "weapon", attrib = "L" },
      },
    }
    boop.onRoomItemsList()

    gmcp.Char.Items.Update = {
      location = "inv",
      item = { id = "11", name = "a curved blade of broken chains", icon = "weapon", attrib = "" },
    }
    boop.onItemsUpdate()
    assert.is_false(boop.state.inventory.wieldedRight)

    gmcp.Char.Items.Add = {
      location = "inv",
      item = { id = "12", name = "a broad-bladed sword of hardship", icon = "weapon", attrib = "l" },
    }
    boop.onRoomItemsAdd()
    assert.are.equal("12", boop.state.inventory.wieldedLeft.id)

    gmcp.Char.Items.Remove = {
      location = "inv",
      item = { id = "12", name = "a broad-bladed sword of hardship", icon = "weapon", attrib = "l" },
    }
    boop.onRoomItemsRemove()
    assert.is_false(boop.state.inventory.wieldedLeft)
  end)

  it("provides copied wielded items through the public getter", function()
    gmcp.Char.Items.List = {
      location = "inv",
      items = {
        { id = "11", name = "a curved blade of broken chains", icon = "weapon", attrib = "L" },
      },
    }
    boop.onRoomItemsList()

    local right = boop.getWieldedItem("right")
    right.name = "changed"

    assert.are.equal("a curved blade of broken chains", boop.state.inventory.wieldedRight.name)
  end)
end)
