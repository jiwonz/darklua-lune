# Example Usage

```lua
local darklua = require("@pkg/darklua")

darklua.process("src.luau", "out.luau", {
	rules = {
		"remove_empty_do",
	}
})

darklua.convert("src.lua", "out.json", "json")

darklua.minify("src.luau", "out.luau")
```
