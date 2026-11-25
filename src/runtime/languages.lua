-- Multi-language registry for VS-RBLX (17 language modes: Luau, TypeScript,
-- JavaScript, Python, JSON, HTML, CSS, Rust, Go, C/C++, C#, Java, SQL,
-- Markdown, YAML/TOML, Shell, and Plain Text).
return function(env)
	local util = env.require("runtime/util")
	local M = {}

	local function wordSet(words)
		local set = {}
		for w in tostring(words or ""):gmatch("%S+") do
			set[w] = true
		end
		return set
	end

	local LIST = {
		{
			id = "luau",
			name = "Luau",
			badge = "LUAU",
			badgeColor = { 0, 162, 255 },
			extensions = { "luau", "lua" },
			lineComment = "--",
			blockComment = { "--[[", "]]" },
			longStrings = true,
			keywords = wordSet("and break do else elseif end false for function if in local nil not or repeat return then true until while continue export type typeof"),
			builtins = wordSet("game workspace script shared plugin task math string table coroutine bit32 utf8 buffer os debug Instance Vector2 Vector3 CFrame Color3 UDim UDim2 Enum TweenInfo RaycastParams OverlapParams NumberSequence ColorSequence Rect Font DateTime Random pcall xpcall ipairs pairs next select unpack tonumber tostring type assert error print warn require loadstring getgenv getrenv gethui readfile writefile appendfile isfile isfolder makefolder listfiles delfile delfolder request http_request setclipboard toclipboard decompile identifyexecutor cloneref hookmetamethod hookfunction getconnections firesignal"),
			types = wordSet("any boolean number string thread table userdata vector buffer never unknown Frame TextLabel TextButton TextBox ScrollingFrame ImageLabel ImageButton ScreenGui UIListLayout UIPadding UICorner UIStroke Part MeshPart Model Folder RemoteEvent RemoteFunction LocalScript ModuleScript Script"),
			snippets = {
				{ trigger = "fn", label = "local function name(...)", insert = "local function main()\n\t\nend" },
				{ trigger = "serv", label = "game:GetService(...)", insert = 'local Players = game:GetService("Players")' },
				{ trigger = "readf", label = "Executor readfile / writefile", insert = 'if isfile("notes.txt") then\n\tlocal data = readfile("notes.txt")\n\tprint(data)\nend' },
				{ trigger = "req", label = "Executor HTTP request", insert = 'local res = request({\n\tUrl = "https://api.github.com/zen",\n\tMethod = "GET",\n})\nprint(res.StatusCode, res.Body)' },
				{ trigger = "mod", label = "ProjectUAI factory module", insert = "return function(env)\n\tlocal M = {}\n\treturn M\nend" },
			},
		},
		{
			id = "typescript",
			name = "TypeScript",
			badge = "TS",
			badgeColor = { 49, 120, 198 },
			extensions = { "ts", "tsx", "mts", "cts" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			decorators = true,
			keywords = wordSet("abstract as async await break case catch class const continue debugger declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let module namespace never new null of override package private protected public readonly return satisfies set static super switch this throw true try type typeof undefined unique var void while with yield"),
			builtins = wordSet("console window document fetch Promise Array Object Map Set WeakMap WeakSet JSON Math Date RegExp Error Symbol BigInt Reflect Proxy setTimeout clearTimeout setInterval clearInterval process Buffer"),
			types = wordSet("string number boolean unknown any void never object symbol bigint Record Partial Required Readonly Pick Omit Exclude Extract Awaited"),
			snippets = {
				{ trigger = "iface", label = "export interface ...", insert = "export interface Props {\n\tid: string;\n}" },
				{ trigger = "afn", label = "async arrow function", insert = "const run = async (): Promise<void> => {\n\t\n};" },
			},
		},
		{
			id = "javascript",
			name = "JavaScript",
			badge = "JS",
			badgeColor = { 241, 224, 90 },
			extensions = { "js", "jsx", "mjs", "cjs" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			decorators = true,
			keywords = wordSet("async await break case catch class const continue debugger default delete do else export extends false finally for from function get if import in instanceof let new null of return set static super switch this throw true try typeof undefined var void while with yield"),
			builtins = wordSet("console window document fetch Promise Array Object Map Set JSON Math Date RegExp Error Symbol parseInt parseFloat isNaN setTimeout setInterval require module exports process"),
			types = wordSet(""),
			snippets = {
				{ trigger = "clg", label = "console.log(...)", insert = "console.log();" },
				{ trigger = "fetch", label = "await fetch JSON", insert = 'const res = await fetch("https://api.github.com");\nconst data = await res.json();' },
			},
		},
		{
			id = "python",
			name = "Python",
			badge = "PY",
			badgeColor = { 53, 114, 165 },
			extensions = { "py", "pyw", "pyi" },
			lineComment = "#",
			tripleStrings = true,
			decorators = true,
			keywords = wordSet("False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case"),
			builtins = wordSet("print len range enumerate zip map filter sorted reversed list dict set tuple str int float bool bytes open isinstance issubclass getattr setattr hasattr super type id hex oct bin min max sum abs round any all dir vars"),
			types = wordSet("Optional Union List Dict Set Tuple Callable Any Sequence Iterable Mapping Path"),
			snippets = {
				{ trigger = "def", label = "def function():", insert = "def main() -> None:\n    pass" },
				{ trigger = "main", label = "if __name__ == '__main__':", insert = 'if __name__ == "__main__":\n    main()' },
			},
		},
		{
			id = "json",
			name = "JSON",
			badge = "{}",
			badgeColor = { 203, 203, 65 },
			extensions = { "json", "jsonc", "manifest" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			jsonMode = true,
			keywords = wordSet("true false null"),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "html",
			name = "HTML",
			badge = "<>",
			badgeColor = { 227, 76, 38 },
			extensions = { "html", "htm", "xml", "svg", "xhtml" },
			blockComment = { "<!--", "-->" },
			markupMode = true,
			keywords = wordSet("DOCTYPE html head body title meta link script style div span section header footer main nav article aside h1 h2 h3 h4 p a button input form label ul ol li table tr td th img canvas svg path"),
			builtins = wordSet("class id style src href type value placeholder name role aria hidden defer async"),
			types = wordSet(""),
			snippets = {
				{ trigger = "html5", label = "HTML5 Document Boilerplate", insert = '<!DOCTYPE html>\n<html lang="en">\n<head>\n\t<meta charset="UTF-8">\n\t<title>Document</title>\n</head>\n<body>\n\t\n</body>\n</html>' },
			},
		},
		{
			id = "css",
			name = "CSS",
			badge = "#",
			badgeColor = { 86, 61, 124 },
			extensions = { "css", "scss", "less" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("important media keyframes import supports layer container root from to solid none auto flex grid block inline absolute relative fixed sticky hidden visible pointer center space-between column row wrap"),
			builtins = wordSet("display position width height min-width max-width min-height max-height margin padding border border-radius background background-color color font-family font-size font-weight line-height gap align-items justify-content flex-direction box-shadow opacity transition transform z-index overflow cursor var calc rgb rgba hsl"),
			types = wordSet("px rem em vh vw deg ms s fr"),
			snippets = {},
		},
		{
			id = "rust",
			name = "Rust",
			badge = "RS",
			badgeColor = { 222, 165, 132 },
			extensions = { "rs" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while"),
			builtins = wordSet("println eprintln format vec panic assert assert_eq Option Some None Result Ok Err Box Rc Arc Vec String Clone Copy Debug Default Drop Iterator Into From"),
			types = wordSet("i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str"),
			snippets = {
				{ trigger = "fn", label = "fn main()", insert = 'fn main() {\n    println!("Hello, VS-RBLX!");\n}' },
			},
		},
		{
			id = "go",
			name = "Go",
			badge = "GO",
			badgeColor = { 0, 173, 216 },
			extensions = { "go" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			templateStrings = true,
			keywords = wordSet("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota"),
			builtins = wordSet("append cap close complex copy delete imag len make new panic print println real recover fmt os io net http context sync time errors"),
			types = wordSet("bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr any comparable"),
			snippets = {},
		},
		{
			id = "cpp",
			name = "C / C++",
			badge = "C++",
			badgeColor = { 243, 75, 125 },
			extensions = { "cpp", "hpp", "cc", "cxx", "c", "h" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			preprocessor = true,
			keywords = wordSet("alignas alignof auto break case catch class const consteval constexpr constinit continue co_await co_return co_yield decltype default delete do else enum explicit export extern false final for friend goto if inline mutable namespace new noexcept nullptr operator override private protected public register reinterpret_cast requires return sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union using virtual volatile while"),
			builtins = wordSet("std cout cin cerr endl vector string map unordered_map set shared_ptr unique_ptr make_shared make_unique move forward printf malloc free"),
			types = wordSet("void bool char short int long float double signed unsigned size_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t"),
			snippets = {},
		},
		{
			id = "csharp",
			name = "C#",
			badge = "C#",
			badgeColor = { 23, 134, 0 },
			extensions = { "cs", "xaml" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			preprocessor = true,
			keywords = wordSet("abstract as async await base break case catch checked class const continue default delegate do else enum event explicit extern false finally fixed for foreach goto if implicit in interface internal is lock namespace new null operator out override params private protected public readonly record ref return sealed sizeof stackalloc static struct switch this throw true try typeof unchecked unsafe using var virtual void volatile while yield"),
			builtins = wordSet("Console Math Task List Dictionary HashSet Enumerable Linq System String Guid DateTime Exception"),
			types = wordSet("bool byte sbyte char decimal double float int uint nint nuint long ulong object short ushort string dynamic"),
			snippets = {},
		},
		{
			id = "java",
			name = "Java",
			badge = "JV",
			badgeColor = { 176, 114, 25 },
			extensions = { "java" },
			lineComment = "//",
			blockComment = { "/*", "*/" },
			decorators = true,
			keywords = wordSet("abstract assert break case catch class const continue default do else enum exports extends false final finally for goto if implements import instanceof interface module native new non-sealed null open opens package permits private protected provides public record requires return sealed static strictfp super switch synchronized this throw throws to transient transitive true try uses var volatile while with yield"),
			builtins = wordSet("System out println String Math List ArrayList Map HashMap Set HashSet Optional Stream Collections Objects Thread Runnable Override"),
			types = wordSet("boolean byte char short int long float double void"),
			snippets = {},
		},
		{
			id = "sql",
			name = "SQL",
			badge = "SQL",
			badgeColor = { 227, 140, 0 },
			extensions = { "sql" },
			lineComment = "--",
			blockComment = { "/*", "*/" },
			caseInsensitive = true,
			keywords = wordSet("select from where insert into values update set delete create alter drop table index view trigger procedure function database schema primary foreign key references unique check default null not and or in between like ilike is exists join inner left right full outer cross on group by having order asc desc limit offset union all distinct as case when then else end begin commit rollback transaction with recursive returning"),
			builtins = wordSet("count sum avg min max coalesce nullif cast convert lower upper trim length substring concat now current_timestamp date_trunc row_number rank dense_rank"),
			types = wordSet("int integer bigint smallint serial text varchar char boolean bool float double numeric decimal date time timestamp timestamptz uuid json jsonb blob bytea"),
			snippets = {},
		},
		{
			id = "markdown",
			name = "Markdown",
			badge = "MD",
			badgeColor = { 81, 154, 186 },
			extensions = { "md", "markdown", "mdx" },
			markdownMode = true,
			keywords = wordSet(""),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "yaml",
			name = "YAML / TOML",
			badge = "YML",
			badgeColor = { 203, 23, 30 },
			extensions = { "yaml", "yml", "toml", "ini", "cfg", "env" },
			lineComment = "#",
			jsonMode = true,
			keywords = wordSet("true false null yes no on off"),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "shell",
			name = "Shell / Bash",
			badge = "SH",
			badgeColor = { 137, 224, 81 },
			extensions = { "sh", "bash", "zsh", "ps1", "bat", "cmd" },
			lineComment = "#",
			keywords = wordSet("if then else elif fi case esac for select while until do done in function time coproc export local readonly declare typeset unset shift return exit break continue trap source alias"),
			builtins = wordSet("echo printf cd pwd ls cp mv rm mkdir rmdir touch cat head tail grep sed awk find xargs sort uniq wc curl wget git gh node npm python3 luajit chmod chown tar zip unzip"),
			types = wordSet(""),
			snippets = {},
		},
		{
			id = "plaintext",
			name = "Plain Text",
			badge = "TXT",
			badgeColor = { 150, 150, 150 },
			extensions = { "txt", "log", "gitignore", "gitattributes", "license" },
			keywords = wordSet(""),
			builtins = wordSet(""),
			types = wordSet(""),
			snippets = {},
		},
	}

	local PREVIEWABLE = {
		html = true,
		css = true,
		markdown = true,
		json = true,
		yaml = true,
		sql = true,
		python = true,
		javascript = true,
		typescript = true,
	}

	local byId = {}
	local byExt = {}
	for _, lang in ipairs(LIST) do
		lang.previewable = PREVIEWABLE[lang.id] == true
		byId[lang.id] = lang
		for _, ext in ipairs(lang.extensions) do
			byExt[ext:lower()] = lang
		end
	end

	M.list = LIST
	M.byId = byId

	function M.get(id)
		return byId[tostring(id or ""):lower()] or byId.plaintext
	end

	function M.isPreviewable(langIdOrDoc)
		if type(langIdOrDoc) == "table" then
			if langIdOrDoc.isDiff then return false end
			return PREVIEWABLE[tostring(langIdOrDoc.langId or ""):lower()] == true
		end
		return PREVIEWABLE[tostring(langIdOrDoc or ""):lower()] == true
	end

	function M.detect(path, content)
		local base = util.basename(path):lower()
		if base == "dockerfile" then return byId.shell end
		if base == "makefile" then return byId.shell end
		if base == "license" or base == "readme" then return byId.plaintext end
		if base == ".gitignore" or base == ".gitattributes" then return byId.plaintext end
		if base == ".env" then return byId.yaml end
		local ext = util.extname(path)
		if ext ~= "" and byExt[ext] then
			return byExt[ext]
		end
		local firstLine = tostring(content or ""):match("^([^\r\n]*)") or ""
		if firstLine:match("^#!/.*python") then return byId.python end
		if firstLine:match("^#!/.*node") then return byId.javascript end
		if firstLine:match("^#!/.*sh") or firstLine:match("^#!/.*bash") then return byId.shell end
		if firstLine:match("^%-%-!") then return byId.luau end
		return byId.luau
	end

	return M
end
