local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop ih", function()
  local echo_stub
  local echoes
  local saved_cecho
  local saved_cecho_link
  local saved_echo
  local saved_echo_link

  before_each(function()
    helper.reset()
    helper.setArea("Test Area")
    helper.setDenizens({
      { id = "42", name = "a test denizen" },
    })

    echoes = {}
    echo_stub = stub(boop.util, "echo", function(msg)
      echoes[#echoes + 1] = msg
    end)

    saved_cecho = _G.cecho
    saved_cecho_link = _G.cechoLink
    saved_echo = _G.echo
    saved_echo_link = _G.echoLink
    _G.cecho = nil
    _G.cechoLink = nil
    _G.echo = nil
    _G.echoLink = nil
  end)

  after_each(function()
    if echo_stub then
      echo_stub:revert()
      echo_stub = nil
    end
    _G.cecho = saved_cecho
    _G.cechoLink = saved_cecho_link
    _G.echo = saved_echo
    _G.echoLink = saved_echo_link
  end)

  it("suppresses ih whitelist and blacklist labels for globally blacklisted denizens", function()
    helper.setGlobalBlacklist({ "a test denizen" })

    boop.ih.printLine("42", "a test denizen", true, "42  a test denizen")

    assert.are.equal("42  a test denizen", echoes[1])
  end)

  it("shows ih whitelist and blacklist labels for non-global denizens", function()
    boop.ih.printLine("42", "a test denizen", true, "42  a test denizen")

    assert.are.equal("42  a test denizen [+whitelist] [+blacklist]", echoes[1])
  end)

  it("keeps the ih trigger broad enough for apostrophes in object ids", function()
    local testsDir = assert(os.getenv("TESTS_DIRECTORY"))
    local repoRoot = assert(testsDir:match("^(.*)/tests$"))
    local handle = assert(io.open(repoRoot .. "/src/triggers/boop/IH/triggers.json", "r"))
    local contents = assert(handle:read("*a"))
    handle:close()

    assert.is_true(contents:find([["pattern": "^(\\S+\\d+)\\s+(.+)$"]], 1, true) ~= nil)
  end)
end)
