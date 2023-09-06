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
    return false, "oas3_spec must be a non-empty string"
  end

  is_valid = is_url_or_file_path(plugin.config.oas3_spec)
  if not is_valid then
    return false, "oas3_spec field only a local path or remote URL"
  end

  return true
end

local function validate_openai_fields(plugin)
  if plugin.config.mode == "auto-agent" then
    if not plugin.config.openai_api_key then
      return false, "openai_api_key is required when mode is 'auto-agent'"
    end
    if not plugin.config.openai_model then
      return false, "openai_model is required when mode is 'auto-agent'"
    end
    if plugin.config.openai_model ~= "gpt-3.5-turbo-0613" and plugin.config.openai_model ~= "gpt-4-0613" then
      return false, "The openai_model must be either 'gpt-3.5-turbo-0613' or 'gpt-4-0613' when mode is 'auto-agent'"
    end
  end
  return true
end

return {
  --consumer = typedefs.no_consumer,
  name = "kong-mocking-advanced",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          { oas3_spec = { type = "string", required = true, }, },
          { mode = { type = "string", default = "auto",
            one_of = { "auto", "auto-agent", "example_literal", "example_template" } }, },
          { validate_requests = { type = "boolean", default = false }, },
          { response_code_hint_source = { type = "string", default = "x-kong-response-code" }, },
          { openai_api_key = { type = "string", required = false, referenceable = true }, },
          {
            openai_prompt_messages = {
              type = "array",
              elements = {
                type = "record",
                fields = {
                  { role = { type = "string", required = false,} },
                  { content = { type = "string", required = false,} },
                }
              },
            }
          },
          {
            openai_model = {
              type = "string",
              required = false,
            }
          },
          {
            openai_model_temperature = {
              type = "number",
              required = false, -- change to true if you want this to be mandatory
            }
          },
          {
            openai_mock_fn_description = {
              type = "string",
              required = false, -- change to true if you want this to be mandatory
            }
          },
        },
      }
    },
  },
  entity_checks = {
    {
      custom_entity_check = {
        field_sources = { "config" },
        fn = validate_oas3_spec,
      }
    },
    {
      custom_entity_check = {
        field_sources = { "config" },
        fn = validate_openai_fields,
      }
    },    
  },
}
