local process = require("@lune/process")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local dirs = require("../lune_packages/dirs")
local gt = require("../luau_packages/greentea")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local stringType = gt.build(gt.string())

--[=[
	@class darklua

	darklua + lune scriptable CLI interface
]=]
local darklua = {}

local function handleDarkluaProcessResult(result: process.ExecResult)
	if not result.ok then
		stdio.ewrite(`{ERROR_PREFIX} darklua process failure.\n\nstdout: {result.stdout}\n\nstderr: {result.stderr}\n`)
		process.exit(1)
		error("unreachable")
	end
end

local configType = gt.build(gt.opt(gt.union(gt.anyTable(), gt.string())))
--[=[
	@within darklua

	Processes a Lua file with DarkLua, applying the specified configuration.

	@param input -- The input Lua file to process.
	@param output -- The output file where the processed Lua code will be written.
	@param config -- Optional configuration for DarkLua, can be a table or a string path to a config file.
	@param spawnOptions -- Optional spawn options for the process execution.
]=]
function darklua.process(
	input: typeof(stringType:type()),
	output: typeof(stringType:type()),
	config: typeof(configType:type()),
	spawnOptions: process.ExecOptions?
)
	assert(stringType(input))
	assert(stringType(output))
	assert(configType(config))

	local args = {
		"process",
		input,
		output,
	}
	if config then
		if type(config) == "string" then
			table.insert(args, "--config")
			table.insert(args, config)
		else
			local darkluaConfigFile = dirs.createTempFile()
			darkluaConfigFile:writeFile(serde.encode("json", config))

			table.insert(args, "--config")
			table.insert(args, darkluaConfigFile.path:toString())
		end
	end

	local result = process.exec("darklua", args, spawnOptions)
	handleDarkluaProcessResult(result)
end

local formatType = gt.build(gt.union(gt.literal("json"), gt.literal("json5"), gt.literal("yaml"), gt.literal("toml")))
local optionalStringType = gt.build(gt.opt(gt.string()))
--[=[
	@within darklua

	Converts a Lua file to a specified format using DarkLua.

	@param input -- The input Lua file to convert.
	@param output -- The output file where the converted code will be written. If nil, the result is returned as a string.
	@param format -- The format to convert the Lua code into (e.g., "json", "json5", "yaml", "toml").
	@param spawnOptions -- Optional spawn options for the process execution.
	@return string? -- If output is nil, returns the converted code as a string; otherwise, writes to the output file.
]=]
local function convert(
	input: typeof(stringType:type()),
	output: typeof(optionalStringType:type()),
	format: typeof(formatType:type()),
	spawnOptions: process.ExecOptions?
): string?
	assert(stringType(input))
	assert(optionalStringType(output))
	assert(formatType(format))

	local result = process.exec("darklua", {
		"convert",
		input,
		output or nil :: any,
		"--format",
		format,
	}, spawnOptions)
	handleDarkluaProcessResult(result)

	if output then
		return result.stdout
	end
	return
end
darklua.convert = (
	convert :: any
) :: ((input: string, output: string, format: typeof(formatType:type())) -> ()) & ((input: string, output: nil, format: typeof(formatType:type())) -> string)

local optionalNumberType = gt.build(gt.opt(gt.number()))
--[=[
	@within darklua

	Minifies a Lua file using DarkLua.

	@param input -- The input Lua file to minify.
	@param output -- The output file where the minified code will be written.
	@param columnSpan -- Optional column span for the minification.
	@param spawnOptions -- Optional spawn options for the process execution.
]=]
function darklua.minify(
	input: typeof(stringType:type()),
	output: typeof(stringType:type()),
	columnSpan: typeof(optionalNumberType:type()),
	spawnOptions: process.ExecOptions?
)
	assert(stringType(input))
	assert(stringType(output))
	assert(optionalNumberType(columnSpan))

	local args = {
		"minify",
		input,
		output,
	}
	if columnSpan then
		table.insert(args, "--column-span")
		table.insert(args, tostring(columnSpan))
	end

	local result = process.exec("darklua", args, spawnOptions)
	handleDarkluaProcessResult(result)
end

table.freeze(darklua)

return darklua
