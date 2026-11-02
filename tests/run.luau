--!strict
-- Copyright (c) 2026 Douglas (Roblox: XXmello_iceXX). All rights reserved. Not licensed for reuse.
local fs = require("@lune/fs")
local process = require("@lune/process")

local expect = require("./Expect")
local Loader = require("./Loader")

export type Test = (name: string, body: () -> ()) -> ()
export type Spec = (test: Test, expect: typeof(expect), load: (path: string) -> any) -> ()

local SPEC_DIR = "tests/specs"

local passed, failed = 0, 0
local failures: { string } = {}

local files = fs.readDir(SPEC_DIR)
table.sort(files)

for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		local specName = string.gsub(file, "%.spec%.luau$", "")
		local spec = require(`./specs/{specName}.spec`) :: Spec
		print(specName)
		spec(
			function(name: string, body: () -> ())
				local ok, err = pcall(body)
				if ok then
					passed += 1
					print(`  ok    {name}`)
				else
					failed += 1
					print(`  FAIL  {name}\n        {tostring(err)}`)
					table.insert(failures, `{specName}: {name}`)
				end
			end,
			expect,
			function(path: string): any
				return Loader.Require(`src/{path}`)
			end
		)
	end
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	for _, name in failures do
		print(`  {name}`)
	end
	process.exit(1)
end
