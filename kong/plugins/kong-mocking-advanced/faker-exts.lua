local faker_exts = {}
function faker_exts.generate_uri()
  local schema = math.random() > 0.5 and "http" or "https"
  local domain = ""
  for i = 1, math.random(1, 4) do
    domain = domain .. string.char(math.random(97, 122))
  end
  domain = domain .. ".tld"
  local path = "/" .. string.char(math.random(97, 122))
  for i = 1, math.random(1, 10) do
    path = path .. string.char(math.random(97, 122))
  end
  local query = ""
  for i = 1, math.random(1, 3) do
    local key = ""
    for i = 1, math.random(1, 5) do
      key = key .. string.char(math.random(97, 122))
    end
    local value = ""
    for i = 1, math.random(1, 5) do
      value = value .. string.char(math.random(97, 122))
    end
    query = query .. key .. "=" .. value .. "&"
  end
  query = string.sub(query, 1, -2)
  return schema .. "://" .. domain .. path .. "?" .. query
end

function faker_exts.generate_ipv4()
  local parts = {}
  for i = 1, 4 do
    table.insert(parts, math.random(0, 255))
  end
  return table.concat(parts, ".")
end

function faker_exts.generate_ipv6()
  local parts = {}
  for i = 1, 8 do
    local part = ""
    for j = 1, 4 do
      part = part .. string.format("%x", math.random(0, 15))
    end
    table.insert(parts, part)
  end
  return table.concat(parts, ":")
end

return faker_exts