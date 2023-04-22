local plugin_name = ({ ... })[1]:match("^kong%.plugins%.([^%.]+)")
local oas3_utils = require("kong.plugins.kong-mocking-advanced.oas3-utils")
local typedefs = require "kong.db.schema.typedefs"

local function is_url_or_file_path(str)
  -- check if the string starts with http or https (case insensitive)
  if string.match(string.lower(str), '^https?://') then
    return true
  end
  
  -- check if the string starts with file://
  if string.match(str, '^file://') then
    return true
  end
  
  -- check if the string is a relative or absolute file path
  if string.match(str, '^/') or string.match(str, '^%w:/') then
    return true
  end
  
  -- if none of the above conditions match, return false
  return false
end


local function validate_oas3_spec(plugin)
  if not plugin.config.oas3_spec or type(plugin.config.oas3_spec) ~= "string" then
    return false,  "oas3_spec must be a non-empty string"
  end

  is_valid = is_url_or_file_path(plugin.config.oas3_spec)
  if not is_valid then
    return false, "oas3_spec field only a local path or remote URL"
  end  

  return true 
end

return {
  --consumer = typedefs.no_consumer,
  name = "kong-mocking-advanced",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",   
      fields = { 
        { oas3_spec = { type = "string", required = true, },},
        { mode = { type = "string", default = "auto", one_of = { "auto", "example_literal", "example_template" } },},
        { validate_requests = { type = "boolean", default = false },},
        { response_code_hint_source = { type = "string", default = "x-kong-response-code" },},
       },  
    } },  
  },
  entity_checks = {
    {
      custom_entity_check = {
        field_sources = { "config" },
        fn = validate_oas3_spec,
      }
    },
  },
}
