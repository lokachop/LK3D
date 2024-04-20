
file = {
	".",
}

module_file = {}

dir = "docs/html"
project = "LK3D"
title = "LK3D Docs"

no_space_before_args = true
format = "markdown"
topics = "docs/manual"
use_markdown_titles = true
kind_names = {topic = "Manual"}
merge = true
sort_modules = true
no_lua_ref = true
template = "docs/templates"

custom_tags = {
	{"internal", hidden = true},
	{"deprecated", hidden = true},
	{"warning", hidden = true}
}





-- standard types
tparam_alias("string", "string")
tparam_alias("bool", "boolean")
tparam_alias("func", "function")
tparam_alias("player", "Player")
tparam_alias("entity", "Entity")
tparam_alias("color", "color")
tparam_alias("table", "table")
tparam_alias("material", "material")
tparam_alias("vector", "vector")
tparam_alias("angle", "angle")