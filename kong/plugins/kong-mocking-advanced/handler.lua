local json = require "cjson.safe"
local cjson = require("cjson")
local yaml = require("lyaml")
local inspect = require("inspect")
local faker = require("faker")
local funcs = require("aspect.funcs")
local aspect = require("aspect.template").new({ debug = true })
local jsonschema = require("resty.ljsonschema")
local oas3_utils = require("kong.plugins.kong-mocking-advanced.oas3-utils")
local faker_exts = require("kong.plugins.kong-mocking-advanced.faker-exts")
local KongMockingHandler = {}

local function determine_response_model(path, verb, content_type, expected_response_code, resolved_spec)
  local exact_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses[expected_response_code] and
  resolved_spec.paths[path][verb].responses[expected_response_code].content[content_type] and
  resolved_spec.paths[path][verb].responses[expected_response_code].content[content_type]['schema']

  if exact_match then
    return exact_match
  end

  local partial_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses.default and
  resolved_spec.paths[path][verb].responses.default.content[content_type] and
  resolved_spec.paths[path][verb].responses.default.content[content_type]['schema']

  if partial_match then
    return partial_match
  end

  local template_paths = {}
  for template_path, _ in pairs(resolved_spec.paths) do
    if template_path:match('{') then
      table.insert(template_paths, template_path)
    end
  end

  local longest_prefix = ''
  local matching_template_path = nil

  for _, template_path in ipairs(template_paths) do
    if string.match(path, '^' .. string.gsub(template_path, '{.-}', '([%%w_-]+)') .. '$') then
      if #template_path > #longest_prefix then
        longest_prefix = template_path
        matching_template_path = template_path
      end
    end
  end

  if matching_template_path then
    local path_variables = {}
    for variable in matching_template_path:gmatch('{.-}') do
      table.insert(path_variables, variable:sub(2, -2))
    end

    local path_regex = '^' .. string.gsub(matching_template_path, '{.-}', '([%%w_-]+)') .. '$'
    local path_matches = { string.match(path, path_regex) }

    local template_match = resolved_spec.paths[matching_template_path] and
    resolved_spec.paths[matching_template_path][verb] and resolved_spec.paths[matching_template_path][verb].responses

    if template_match then
      if template_match[expected_response_code].content[content_type]['schema'] then
        return template_match[expected_response_code].content[content_type]['schema']
      elseif template_match.default then
        return template_match.default.content[content_type]['schema']
      end
    end
  end

  return nil
end

local function determine_response_example(path, verb, content_type, expected_response_code, resolved_spec)
  local exact_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses[expected_response_code] and
  resolved_spec.paths[path][verb].responses[expected_response_code].content[content_type] and
  resolved_spec.paths[path][verb].responses[expected_response_code].content[content_type]
  if exact_match and exact_match.examples then
    local examples = exact_match
    local example_keys = {}
    for key, _ in pairs(exact_match.examples) do
      table.insert(example_keys, key)
    end
    local random_key = example_keys[math.random(#example_keys)]
    return exact_match.examples[random_key]
  elseif exact_match.example then
    return exact_match.example
  end

  local partial_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses.default and
  resolved_spec.paths[path][verb].responses.default.content[content_type] and
  resolved_spec.paths[path][verb].responses.default.content[content_type]

  if partial_match and partial_match.examples then
    local examples = partial_match
    local example_keys = {}
    for key, _ in pairs(examples) do
      table.insert(example_keys, key)
    end
    local random_key = example_keys[math.random(#example_keys)]
    return examples[random_key].value
  elseif partial_match.example then
    return partial_match.example
  end

  local template_paths = {}
  for template_path, _ in pairs(resolved_spec.paths) do
    if template_path:match('{') then
      table.insert(template_paths, template_path)
    end
  end

  local longest_prefix = ''
  local matching_template_path = nil

  for _, template_path in ipairs(template_paths) do
    if string.match(path, '^' .. string.gsub(template_path, '{.-}', '([%%w_-]+)') .. '$') then
      if #template_path > #longest_prefix then
        longest_prefix = template_path
        matching_template_path = template_path
      end
    end
  end

  if matching_template_path then
    local path_variables = {}
    for variable in matching_template_path:gmatch('{.-}') do
      table.insert(path_variables, variable:sub(2, -2))
    end

    local path_regex = '^' .. string.gsub(matching_template_path, '{.-}', '([%%w_-]+)') .. '$'
    local path_matches = { string.match(path, path_regex) }

    local template_match = resolved_spec.paths[matching_template_path] and
    resolved_spec.paths[matching_template_path][verb] and resolved_spec.paths[matching_template_path][verb].responses

    if template_match then
      if template_match[expected_response_code].content[content_type]['examples'] then
        local examples = template_match[expected_response_code].content[content_type]['examples']
        local example_keys = {}
        for key, _ in pairs(examples) do
          table.insert(example_keys, key)
        end
        local random_key = example_keys[math.random(#example_keys)]
        return examples[random_key].value
      elseif template_match[expected_response_code].content[content_type]['example'] then
        return template_match[expected_response_code].content[content_type]['example']
      elseif template_match.default then
        if template_match.default.content[content_type]['examples'] then
          local examples = template_match.default.content[content_type]['examples']
          local example_keys = {}
          for key, _ in pairs(examples) do
            table.insert(example_keys, key)
          end
          local random_key = example_keys[math.random(#example_keys)]
          return examples[random_key].value
        elseif template_match.default.content[content_type]['example'] then
          return template_match.default.content[content_type]['example']
        end
      end
    end
  end

  return nil
end

local function determine_response_headers(path, verb, content_type, expected_response_code, resolved_spec)
  local exact_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses and resolved_spec.paths[path][verb].responses[expected_response_code] and
  resolved_spec.paths[path][verb].responses[expected_response_code].headers

  if exact_match then
    return exact_match
  end


  local partial_match = resolved_spec.paths[path] and resolved_spec.paths[path][verb] and
  resolved_spec.paths[path][verb].responses.default and resolved_spec.paths[path][verb].responses.default.headers

  if partial_match then
    return partial_match
  end


  local template_paths = {}
  for template_path, _ in pairs(resolved_spec.paths) do
    if template_path:match('{') then
      table.insert(template_paths, template_path)
    end
  end

  local longest_prefix = ''
  local matching_template_path = nil

  for _, template_path in ipairs(template_paths) do
    if string.match(path, '^' .. string.gsub(template_path, '{.-}', '([%%w_-]+)') .. '$') then
      if #template_path > #longest_prefix then
        longest_prefix = template_path
        matching_template_path = template_path
      end
    end
  end

  if matching_template_path then
    local path_variables = {}
    for variable in matching_template_path:gmatch('{.-}') do
      table.insert(path_variables, variable:sub(2, -2))
    end

    local path_regex = '^' .. string.gsub(matching_template_path, '{.-}', '([%%w_-]+)') .. '$'
    local path_matches = { string.match(path, path_regex) }

    local template_match = resolved_spec.paths[matching_template_path] and
    resolved_spec.paths[matching_template_path][verb] and resolved_spec.paths[matching_template_path][verb].responses

    if template_match then
      if template_match[expected_response_code].headers then
        return template_match[expected_response_code].headers
      elseif template_match.default then
        return template_match.default.headers
      end
    end
  end

  return nil
end

local function determine_request_headers(path, verb, resolved_spec)
  local headers = {}

  -- Check for query parameters defined in the path
  if resolved_spec.paths[path] and resolved_spec.paths[path][verb] and resolved_spec.paths[path][verb].parameters then
    for _, param in ipairs(resolved_spec.paths[path][verb].parameters) do
      if param['in'] == 'header' then
        local header_key = param['name']
        headers[header_key] = param
      end
    end
  end

  return headers
end

local function determine_query_parameters(path, verb, resolved_spec)
  local query_parameters = {}

  -- Check for query parameters defined in the path
  if resolved_spec.paths[path] and resolved_spec.paths[path][verb] and resolved_spec.paths[path][verb].parameters then
    for _, param in ipairs(resolved_spec.paths[path][verb].parameters) do
      if param['in'] == 'query' then
        local param_key = param['name']
        query_parameters[param_key] = param
      end
    end
  end
  return query_parameters
end

local function determine_request_body_schema(path, verb, content_type, resolved_spec)
  -- Check for a request body schema defined in the path
  if resolved_spec.paths[path] and resolved_spec.paths[path][verb] and resolved_spec.paths[path][verb].requestBody then
    local request_body = resolved_spec.paths[path][verb].requestBody
    if request_body.content and request_body.content[content_type] and request_body.content[content_type].schema then
      return request_body.content[content_type].schema
    end
  end
  return nil
end

-- Create a new instance of the Faker object
local fake = faker:new()

local function kong_faker_mock_response(schema)
  if schema.oneOf then
    local selected_schema = schema.oneOf[math.random(#schema.oneOf)]
    return kong_faker_mock_response(selected_schema)
  elseif schema.anyOf then
    local selected_schema = schema.anyOf[math.random(#schema.anyOf)]
    return kong_faker_mock_response(selected_schema)
  elseif schema.allOf then
    local mock_data = {}
    for _, sub_schema in ipairs(schema.allOf) do
      local sub_data = kong_faker_mock_response(sub_schema)
      for key, value in pairs(sub_data) do
        mock_data[key] = value
      end
    end
    return mock_data
  elseif schema.type == "array" then
    local array_items = {}
    for i = 1, math.random(1, 10) do
      table.insert(array_items, kong_faker_mock_response(schema.items))
    end
    return array_items
  end

  local mock_data = {}
  if schema.type == "string" then
    if schema.enum then
      mock_data = schema.enum[math.random(#schema.enum)]
    elseif schema.format == "date-time" then
      mock_data = os.date("!%Y-%m-%dT%H:%M:%S") .. "Z"
    elseif schema.format == "date" then
      mock_data = os.date("!%Y-%m-%d")
    elseif schema.format == "uri" then
      mock_data = faker_exts.generate_uri()
    elseif schema.format == "email" then
      mock_data = fake:email()
    elseif schema.format == "ipv4" then
      mock_data = faker_exts.generate_ipv4()
    elseif schema.format == "ipv6" then
      mock_data = faker_exts.generate_ipv6()
    else
      mock_data = fake:name()
    end
  elseif schema.type == "number" then
    if schema.format == "float" or schema.format == "double" then
      mock_data = math.random() + math.random(0, 1000)
    else
      mock_data = math.random(0, 1000) + math.random()
    end
  elseif schema.type == "integer" then
    if schema.format == "int32" then
      mock_data = math.random(0, 2147483647)
    elseif schema.format == "int64" then
      mock_data = math.random(0, 9223372036854775807)
    else
      mock_data = math.random(0, 1000)
    end
  elseif schema.type == "boolean" then
    mock_data = math.random() > 0.5
  elseif schema.type == "object" then
    for key, value in pairs(schema.properties) do
      mock_data[key] = kong_faker_mock_response(value)
    end
  end
  return mock_data
end

local function kong_compile_example_template(template, context)
  funcs.add("generate_string", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake.randstring()
  end)
  funcs.add("generate_number", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake.randint(10)
  end)
  funcs.add("generate_name", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake:name()
  end)
  funcs.add("generate_email", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake:email()
  end)
  funcs.add("generate_country", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake:country()
  end)
  funcs.add("generate_state", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake:state()
  end)
  funcs.add("generate_city", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return fake:city()
  end)
  funcs.add("generate_uri", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return faker_exts.generate_uri()
  end)
  funcs.add("generate_ipv4", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return faker_exts.generate_ipv4()
  end)
  funcs.add("generate_ipv6", { args = nil, }, function(__, args)
    --local fake = faker:new()
    return faker_exts.generate_ipv6()
  end)

  -- Evaluate the template with the context
  local result, err = aspect:eval(template, context)

  if err then
    return nil, err
  end

  return result
end


local function validate_request_parameters(param_schemas, provided_params, ignore_undefined_params)
  local ignore_undefined_params = ignore_undefined_params or true
  local validations = {}
  local errors = false
  local error_messages = {}

  -- Determine matching schema for each supplied parameter
  for name, value in pairs(provided_params) do
    local schema = param_schemas[name] or false
    -- if we can't find a schema for the param, it means it is an extraneous param
    -- we can choose to igore it and continue validating others (if ignore_undefined_params is true, which is by default)
    -- (OR) raise an error that a param was found with no schema to validate against (if false)
    if not schema or not schema['schema'] then
      if not ignore_undefined_params then
        errors = true
        error_messages[schema] = "No schema found for parameter: " .. name
      end
      -- error("No schema found for parameter: " .. name)
    else
      local validator = jsonschema.generate_validator(schema['schema'], { coercion = true })
      local result, err = validator(value)
      if err then
        validations[schema.name] = "invalid"
        errors = true
        error_messages[schema.name] = err
      else
        validations[schema.name] = "valid"
      end
    end
  end
  -- Check if any required schemas have failed validation
  for schema_key, schema in pairs(param_schemas) do
    if schema.required and not validations[schema_key] then
      errors = true
      error_messages[schema_key] = "Required parameter validation failed: " .. schema_key
      --error("Required parameter validation failed: " .. schema.name)
    end
  end
  if errors then
    return error_messages, errors
  end

  return validations
end

local function validate_request_body(param_schemas, body, ignore_undefined_params)
  local ignore_undefined_params = ignore_undefined_params or true
  local validator = jsonschema.generate_validator(param_schemas, { coercion = true })
  local result, err = validator(body)
  if err then
    return err, err -- weird but no time
  else
    return result
  end
end

local function table_to_xml(data, root_name)
  local root = root_name or "root"
  local xml = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
  xml = xml .. "<" .. root .. ">"

  for key, value in pairs(data) do
    local value_type = type(value)
    if value_type == "table" then
      xml = xml .. table_to_xml(value, key)
    elseif value_type == "boolean" then
      xml = xml .. "<" .. key .. ">" .. tostring(value) .. "</" .. key .. ">"
    else
      xml = xml .. "<" .. key .. ">" .. tostring(value) .. "</" .. key .. ">"
    end
  end

  xml = xml .. "</" .. root .. ">"

  return xml
end

local function kong_get_current_context()
  local context = {}
  context['request'] = {}
  context['request']['headers'] = kong.request.get_headers()
  context['request']['query'] = {}
  for k, v in pairs(kong.request.get_query()) do
    context['request']['query'][k] = v
  end
  context['request']['path'] = kong.request.get_path()
  context['request']['method'] = kong.request.get_method()
  context['request']['body'] = kong.request.get_body()
  context['request']['raw_body'] = kong.request.get_raw_body()
  context['request']['time'] = kong.request.get_start_time()
  context['client'] = {}
  context['client']['ip'] = kong.client.get_ip() 
  context['client']['consumer'] = kong.client.get_consumer()
  return context
end

function KongMockingHandler:access(conf)

  local context = kong_get_current_context()
  local spec = oas3_utils.oas_load(oas3_utils.read_spec_from_input(conf.oas3_spec))

  local resolved_spec, err = oas3_utils.resolve_json_references(spec)

  local path = kong.request.get_path()
  local verb = kong.request.get_method()

  local content_type = kong.request.get_header("Content-Type") or "application/json"
  local response_hint = kong.request.get_header(conf.response_code_hint_source)

  if conf.validate_requests == true then
    local req_headers_schema = determine_request_headers(path, verb:lower(), resolved_spec)
    if req_headers_schema and context.request.headers then
      local validate_req_headers, err = validate_request_parameters(req_headers_schema, context.request.headers)
      if err then
        kong.response.exit(400, validate_req_headers)
      end
    end

    local query_params_schema = determine_query_parameters(path, verb:lower(), resolved_spec)
    if query_params_schema and context.request.query then
      local validate_query_params, err = validate_request_parameters(query_params_schema, context.request.query)
      if err then
        kong.response.exit(400, validate_query_params)
      end
    end

    local req_body_schema = determine_request_body_schema(path, verb:lower(), content_type, resolved_spec)
    if req_body_schema and context.request.body then
      local validate_body_schema, err = validate_request_body(req_body_schema, context.request.body)
      if err then
        kong.response.exit(400, validate_body_schema)
      end
    end
  end

  local response_headers = determine_response_headers(path, verb:lower(), content_type, response_hint, resolved_spec)
  local headers = {["X-Generator"] = "kong-faker-v0.1"}
  if response_headers then
    for key, value in pairs(response_headers) do
      if value.schema then
        headers[key] = kong_faker_mock_response(value['schema'])
      end
    end
  end

  local response_body = {}

  if conf.mode == 'auto' then
    local response_model = determine_response_model(path, verb:lower(), content_type, response_hint, resolved_spec)
    kong.log.inspect(response_model)
    if not response_model then
      kong.response.exit(200,
      "The mocking plugin was unable to determine a response schema. Please check your OpenAPI spec.")
    end

    response_body = kong_faker_mock_response(response_model)
    if content_type == 'application/xml' then
      response_body = table_to_xml(response_body, 'response')
    end

  elseif conf.mode == 'example_literal' or conf.mode == 'example_template' then
    response_body = determine_response_example(path, verb:lower(), content_type, response_hint, resolved_spec)
    if not response_body then
      kong.response.exit(200,
      "The mocking plugin was unable to determine a response example. Please check your OpenAPI spec.")
    end
    if conf.mode == 'example_template' then
      local response_string
      if content_type == 'application/json' then
        response_string = cjson.encode(response_body)
      elseif content_type == 'application/xml' then
        response_string = table_to_xml(response_body, 'response')
      end

      local compiled_str, err = kong_compile_example_template(response_string, context)
      if err then
        kong.log.inspect(err)
      elseif compiled_str then
        response_body = compiled_str.result
      end
    end
  end

  local response_code = response_hint or 200
  kong.response.exit(tonumber(response_hint), response_body, headers)
end

KongMockingHandler.PRIORITY = 1000

KongMockingHandler.VERSION = "0.1.0"
return KongMockingHandler
