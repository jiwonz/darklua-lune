local process = require("@lune/process")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local dirs = require("../lune_packages/dirs")
local gt = require("../lune_packages/greentea")

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`

local stringType = gt.build(gt.string())

local darklua = {}

local function handleDarkluaProcessResult(result: process.SpawnResult)
	if not result.ok then
		stdio.ewrite(`{ERROR_PREFIX} darklua process failure.\n\nstdout: {result.stdout}\n\nstderr: {result.stderr}\n`)
		process.exit(1)
		error("unreachable")
	end
end

local configType = gt.build(gt.opt(gt.union(gt.anyTable(), gt.string())))
function darklua.process(
	input: typeof(stringType:type()),
	output: typeof(stringType:type()),
	config: typeof(configType:type())
)
	stringType:assert(input)
	stringType:assert(output)
	configType:assert(config)

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

	local result = process.spawn("darklua", args, {
		stdio = "forward",
	})
	handleDarkluaProcessResult(result)
end

local formatType = gt.build(gt.union(gt.literal("json"), gt.literal("json5"), gt.literal("yaml"), gt.literal("toml")))
local optionalStringType = gt.build(gt.opt(gt.string()))
darklua.convert = (
	function(
		input: typeof(stringType:type()),
		output: typeof(optionalStringType:type()),
		format: typeof(formatType:type())
	): string?
		stringType:assert(input)
		optionalStringType:assert(output)
		formatType:assert(format)

		local result = process.spawn("darklua", {
			"convert",
			input,
			output or nil :: any,
			"--format",
			format,
		}, {
			stdio = "forward",
		})
		handleDarkluaProcessResult(result)

		if output then
			return result.stdout
		end
		return
	end :: any
) :: ((input: string, output: string, format: typeof(formatType:type())) -> ()) & ((input: string, output: nil, format: typeof(formatType:type())) -> string)

local optionalNumberType = gt.build(gt.opt(gt.number()))
function darklua.minify(
	input: typeof(stringType:type()),
	output: typeof(stringType:type()),
	columnSpan: typeof(optionalNumberType:type())
)
	stringType:assert(input)
	stringType:assert(output)
	optionalNumberType:assert(columnSpan)

	local args = {
		"minify",
		input,
		output,
	}
	if columnSpan then
		table.insert(args, "--column-span")
		table.insert(args, tostring(columnSpan))
	end

	local result = process.spawn("darklua", args, {
		stdio = "forward",
	})
	handleDarkluaProcessResult(result)
end

return darklua
