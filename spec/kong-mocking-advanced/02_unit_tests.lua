local PLUGIN_NAME = "kong-mocking-advanced"
local plugin = require("kong.plugins."..PLUGIN_NAME..".handler")
--local oas3_utils = require("kong.plugins."..PLUGIN_NAME..".oas3_utils")

local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()


  it("accepts HTTP paths for oas3_spec", function()

    local ok, err = validate({
        oas3_spec = "https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/examples/v3.0/petstore.yaml",
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("accepts local file paths for oas3_spec", function()

    local ok, err = validate({
        oas3_spec = "/opt/conf/spec/kong-mocking-advanced/configs/petstore-examples.yaml",
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("does not accept strings that are ot URLs or filepaths", function()
    local ok, err = validate({
        oas3_spec = "just-a-string",
      })

    assert.is_same({
      ["@entity"] = {
        [1] = "oas3_spec field only a local path or remote URL"
      }
    }, err)
    assert.is_falsy(ok)
  end)


end)
