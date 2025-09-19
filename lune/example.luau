local fs = require("@lune/fs")
local darklua = require("../src/lib")

local INPUT = ".playground/test.luau"
local OUTPUT = ".playground/out.luau"

fs.writeDir(".playground")
fs.writeFile(INPUT, [[for i = 1, 10 do if i == 5 then continue end end]])
darklua.process(INPUT, OUTPUT, {
	rules = {
		"remove_continue",
	},
}, {
	shell = true,
})
print(fs.readFile(OUTPUT))
