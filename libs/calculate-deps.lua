local normalize = require('semver').normalize
local gte = require('semver').gte
local log = require('log')
local queryDb = require('pkg').queryDb

return function (db, deps, newDeps)

  local addDep, processDeps

  function processDeps(dependencies)
    for alias, dep in pairs(dependencies) do
      local name, version = dep:match("^([^@]+)@?(.*)$")
      if #version == 0 then
        version = nil
      end
      if type(alias) == "number" then
        alias = name:match("([^/]+)$")
      end
      if not name:find("/") then
        error("Package names must include owner/name at a minimum")
      end
      if version then
        version = normalize(version)
      end
      addDep(alias, name, version)
    end
  end

  function addDep(alias, name, version)
    local meta = deps[alias]
    if meta then
      if name ~= meta.name then
        local message = string.format("%s %s ~= %s",
          alias, meta.name, name)
        log("alias conflict", message, "failure")
        return
      end
      if version then
        if not gte(meta.version, version) then
          local message = string.format("%s %s ~= %s",
            alias, meta.version, version)
          log("version conflict", message, "failure")
          return
        elseif meta.version:match("%d+%.%d+%.%d+") ~= version:match("%d+%.%d+%.%d+") then
          local message = string.format("%s %s ~= %s",
            alias, meta.version, version)
          log("version mismatch", message, "highlight")
        end
      end
    else
      local author, pname = name:match("^([^/]+)/(.*)$")
      local match, hash = db.match(author, pname, version)

      if not match then
        error("No such "
          .. (version and "version" or "package") .. ": "
          .. name
          .. (version and '@' .. version or ''))
      end
      local kind
      meta, kind, hash = assert(queryDb(db, hash))
      meta.db = db
      meta.hash = hash
      meta.kind = kind
      log("using dependency", string.format("%s as %s", hash, alias))
      deps[alias] = meta
    end

    if meta.dependencies then
      processDeps(meta.dependencies)
    end

  end

  processDeps(newDeps)

  return deps
end
