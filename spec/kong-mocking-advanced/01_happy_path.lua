local cjson   = require "cjson"
local helpers = require "spec.helpers"
local utils = require "kong.tools.utils"
local inspect = require('inspect')
local PLUGIN_NAME = "kong-mocking-advanced"
local spec_petstore_basic = "https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/examples/v3.0/petstore-expanded.yaml"


for _, strategy in helpers.each_strategy() do
  describe("Plugin: Kong Mocking Advanced [#" .. strategy .. "]", function()
    local proxy_client
    local bp
    local route1

    lazy_setup(function()
      bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

      route1 = bp.routes:insert {
        hosts = { "petstore.com" },
        paths = { "/" },
        protocols = { "http" },
      }

      bp.plugins:insert {
        name     = "kong-mocking-advanced",
        route = { id = route1.id },
        config   = {
          oas3_spec = spec_petstore_basic,
        }
      }

      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        plugins = "bundled," .. PLUGIN_NAME,
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,        
      }))

      proxy_client = helpers.proxy_client()
    end)
    lazy_teardown(function()
      if proxy_client then
        proxy_client:close()
      end

      helpers.stop_kong()
    end)

    describe("/pets", function()
      describe("GET", function()
        after_each(function()
        end)
        it("should fetch an auto mocked response", function()
          local res = assert(proxy_client:send {
            method  = "GET",
            path    = "/pets",
            headers = {
              host = "petstore.com",
              ["Content-Type"] = "application/json",
              ["x-kong-response-code"] = "200"
            }
          })
          local body = assert.res_status(200, res)
          local pets = assert.is_table(cjson.decode(body))
          for _, pet in ipairs(pets) do
            assert.is_number(pet.id)
            assert.is_string(pet.name)
            assert.is_string(pet.tag)
          end          
        end)
      end)
    end)
  end)
end
