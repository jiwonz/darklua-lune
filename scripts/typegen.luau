local net = require("@lune/net")
local serde = require("@lune/serde")
local unzip = require("../luau_packages/unzip")
local pathfs = require("../lune_packages/pathfs")
local fs = pathfs.fs
local Regex = require("@lune/regex")

local TYPEGEN_PATH = "src/types.luau"
local DARKLUA_RULES_DOCS_PATH = "site/content/rules"
local DARKLUA_ZIP_URL_FORMAT = "https://api.github.com/repos/seaofvoices/darklua/zipball/v%s"
local PESDE_ROOT: string = _G.PESDE_ROOT
if not PESDE_ROOT then
	error("'_G.PESDE_ROOT' was not set. Are you running through 'pesde run'?")
end

local pesdeToml = pathfs.findFile("pesde.toml")
if not pesdeToml then
	error("Could not find 'pesde.toml'.")
end

local darkluaVersion: string do
	local pesdeManifest: {
		version: string?
	} = serde.decode("toml", pesdeToml:readFile())
	if not pesdeManifest.version then
		error("Could not find 'version' in 'pesde.toml'.")
	end
	darkluaVersion = pesdeManifest.version
end

local zipContent = net.request(DARKLUA_ZIP_URL_FORMAT:format(darkluaVersion))
if not zipContent.ok then
	error("Failed to download darklua zip.")
end

local reader = unzip.load(buffer.fromstring(zipContent.body))

local firstEntry = reader:findEntry("/")
if not firstEntry then
	error("Could not find first entry in zip.")
end

local firstChild = firstEntry.children[1]
if not firstChild then
	error("Could not find first child in first entry of zip.")
end

local rulesDocsPath = firstChild.name .. DARKLUA_RULES_DOCS_PATH
if not reader:findEntry(rulesDocsPath) then
	error(`Failed to find {DARKLUA_RULES_DOCS_PATH} directory in downloaded darklua source code`)
end

local function snakeToPascal(str: string)
	return (str:gsub("(%a)([%w_]*)", function(first: string, rest: string)
		return first:upper() .. rest:lower():gsub("_%a", function(letter: string)
			return letter:sub(2):upper()
		end :: any)
	end :: any))
end

local typeAssignments: { string } = {}
local markdownYamlBlockRegex = Regex.new("(?s)---\s*(.*?)\s*---")
for _, entry in reader:listDirectory(rulesDocsPath) do
	local content = reader:extract(entry, {
		isString = true,
	}) :: string
	local entryPath = pathfs.Path.from(entry.name)
	local ruleName = entryPath:fileStem()
	if not ruleName then
		error(`Could not extract rule name from entry path. entry: '{entry.name}'`)
	end
	local ruleStructName = snakeToPascal(ruleName)

	local captures = markdownYamlBlockRegex:captures(content)
	if not captures then
		continue
	end

	local yamlBlock = captures:get(1)
	if not yamlBlock then
		continue
	end

	local docsAPI: {
		parameters: {
			{
				name: string?,
				required: boolean?,
				type: string?,
				description: string?,
			}
		}?,
	} = serde.decode("yaml", yamlBlock.text)

	local typeAssignment = {
		`export type {ruleStructName} = \{`
	}

	if not docsAPI.parameters then
		continue
	end

	for _, parameter in docsAPI.parameters do
		if not parameter.name then
			continue
		end
		if not parameter.type then
			continue
		end
		table.insert(typeAssignment, `\t{parameter.name}: {parameter.type},`)
	end

	table.insert(typeAssignment, "}")
	table.insert(typeAssignments, table.concat(typeAssignment, "\n"))
end
