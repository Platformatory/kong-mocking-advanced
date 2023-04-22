local http = require "resty.http"
local ltn12 = require "ltn12"
local json = require "cjson.safe"
local cjson = require("cjson")
local yaml = require("lyaml")
local oas3_utils = {}


function oas3_utils.read_spec_from_input(input)
  local file, err
  if string.match(input, "^https?://") then
    local httpc = http.new()
    local res, err = httpc:request_uri(input)
    if not res then
      return nil, "Failed to retrieve OAS3 spec from URL: " .. err
    end
    file = res.body
  else
    file, err = io.open(input, "r")
    if not file then
      return nil, "Failed to open file: " .. err
    end
    file = file:read("*a")
    file:close()
  end
  return file
end

function oas3_utils.oas_load(content)
  -- Determine the format of the document
  local format = string.sub(content, 2, 1)
  -- Parse the OAS document
  local oas, err
  if format == "{" then
    oas, err = cjson.decode(content)
  else
    oas, err = yaml.load(content) -- wat. yaml.load fails silently when given invalid YAML
  end

  if(err) then
    return false, err
  end

  return oas
end

function oas3_utils.validate(spec)
  -- Check if spec is a table
  if type(spec) ~= 'table' then
    return false
  end

  -- Check if the OpenAPI version is specified and is 3.x.x
  if not spec.openapi or type(spec.openapi) ~= 'string' or not string.match(spec.openapi, '^3%.[0-9]+%.[0-9]+$') then
    return false
  end

  -- Check if the required fields are present and are tables
  local required_fields = {'info', 'paths'}
  for _, field in ipairs(required_fields) do
    if not spec[field] or type(spec[field]) ~= 'table' then
      return false
    end
  end

  -- Check if info object is valid
  if type(spec.info) ~= 'table' or not spec.info.title or not spec.info.version then
    return false
  end

  -- Check if paths object is valid
  if type(spec.paths) ~= 'table' then
    return false
  end

  return true
end

function oas3_utils.resolve_json_references(data)
  local visited_nodes = {}
  local function resolve_node(node)
    if type(node) ~= "table" or visited_nodes[node] then
      return node
    end
    visited_nodes[node] = true
    for k, v in pairs(node) do
      if type(v) == "table" then
        if v["$ref"] then
          local ref_path = v["$ref"]:gsub("#", "")
          local resolved_ref = data
          for ref_key in ref_path:gmatch("[^/]+") do
            resolved_ref = resolved_ref[ref_key]
          end
          node[k] = resolve_node(resolved_ref)
        else
          node[k] = resolve_node(v)
        end
      end
    end
    return node
  end

  return resolve_node(data)
end

return oas3_utils
