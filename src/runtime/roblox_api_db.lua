-- Comprehensive Roblox Engine, Luau Stdlib & Executor API knowledge base for LSP-style IntelliSense.
-- Pure Lua 5.1-compatible module (no Luau-only syntax).
return function(_env)
	local M = {}

	-- Roblox Services (`game:GetService("<Service>")`)
	M.services = {
		{ name = "Players", doc = "Manages all connected Player instances and LocalPlayer on the client." },
		{ name = "Workspace", doc = "3D world simulation root containing Parts, Models, Terrain, and CurrentCamera." },
		{ name = "ReplicatedStorage", doc = "Shared container replicated between server and all connected clients." },
		{ name = "RunService", doc = "Frame-by-frame loop signals (Heartbeat, RenderStepped, Stepped) and environment flags." },
		{ name = "UserInputService", doc = "Captures keyboard, mouse, touch, and gamepad input across client devices." },
		{ name = "TweenService", doc = "Smoothly interpolates Roblox Instance properties using TweenInfo curves." },
		{ name = "HttpService", doc = "JSON encoding/decoding, GUID generation, and URL encoding utilities." },
		{ name = "Lighting", doc = "Controls skybox, exposure, atmosphere, fog, and time-of-day lighting." },
		{ name = "SoundService", doc = "Global 2D/3D audio playback, SoundGroups, and reverb settings." },
		{ name = "ContextActionService", doc = "Binds context-sensitive input actions and mobile touch buttons." },
		{ name = "CollectionService", doc = "Manages Instance tags for decoupled component architectures." },
		{ name = "TeleportService", doc = "Teleports players between places and reserved game servers." },
		{ name = "MarketplaceService", doc = "Handles gamepasses, developer products, and asset info queries." },
		{ name = "GuiService", doc = "Provides GUI inset metrics, selection navigation, and menu state." },
		{ name = "ProximityPromptService", doc = "Global events for 3D world ProximityPrompt interactions." },
		{ name = "PathfindingService", doc = "Computes 3D navigation meshes and waypoint paths for characters." },
		{ name = "LogService", doc = "Streams live print/warn/error output via MessageOut." },
		{ name = "StarterGui", doc = "Template GUI container and SetCore / SetCoreGuiEnabled controls." },
		{ name = "CoreGui", doc = "Privileged UI root protected above standard player ScreenGuis." },
		{ name = "TextChatService", doc = "Modern Roblox chat channels, commands, and chat window configuration." },
		{ name = "Debris", doc = "Schedules automatic non-yielding Instance cleanup after a lifetime." },
		{ name = "DataStoreService", doc = "Persistent key-value and ordered storage on Roblox servers." },
		{ name = "PhysicsService", doc = "Manages collision groups and physical simulation rules." },
	}

	-- Creatable Roblox ClassNames (`Instance.new("<ClassName>")`)
	M.creatableClasses = {
		{ name = "Frame", base = "GuiObject", doc = "2D rectangular UI container." },
		{ name = "ScrollingFrame", base = "GuiObject", doc = "Scrollable 2D UI container with CanvasSize and scrollbars." },
		{ name = "TextLabel", base = "GuiObject", doc = "2D non-interactive text label supporting RichText." },
		{ name = "TextButton", base = "GuiObject", doc = "Clickable 2D UI button with text." },
		{ name = "TextBox", base = "GuiObject", doc = "Editable single-line or multi-line text input box." },
		{ name = "ImageLabel", base = "GuiObject", doc = "Displays a 2D image asset." },
		{ name = "ImageButton", base = "GuiObject", doc = "Clickable 2D image button." },
		{ name = "ScreenGui", base = "Instance", doc = "Top-level 2D GUI container rendered on a player's screen." },
		{ name = "BillboardGui", base = "Instance", doc = "2D GUI container attached to a 3D world Part or Attachment." },
		{ name = "SurfaceGui", base = "Instance", doc = "2D GUI projected directly onto a face of a 3D BasePart." },
		{ name = "UIListLayout", base = "Instance", doc = "Stacks sibling GuiObjects vertically or horizontally." },
		{ name = "UIGridLayout", base = "Instance", doc = "Arranges sibling GuiObjects in a uniform grid." },
		{ name = "UIPadding", base = "Instance", doc = "Applies inner Top/Bottom/Left/Right padding to a parent GuiObject." },
		{ name = "UICorner", base = "Instance", doc = "Rounds the corners of its parent GuiObject." },
		{ name = "UIStroke", base = "Instance", doc = "Draws an outline or text stroke on its parent GuiObject." },
		{ name = "UIGradient", base = "Instance", doc = "Applies a color/transparency gradient across its parent GuiObject." },
		{ name = "UISizeConstraint", base = "Instance", doc = "Clamps MinSize and MaxSize of a GuiObject." },
		{ name = "Part", base = "BasePart", doc = "Simulated 3D rigid body primitive." },
		{ name = "Model", base = "Instance", doc = "Container grouping 3D BaseParts, Joints, and Humanoids." },
		{ name = "Folder", base = "Instance", doc = "Lightweight organizational container with zero simulation overhead." },
		{ name = "Highlight", base = "Instance", doc = "Renders a 3D silhouette/outline highlight around aPart or Model." },
		{ name = "Attachment", base = "Instance", doc = "3D point/orientation anchor inside a BasePart." },
		{ name = "ProximityPrompt", base = "Instance", doc = "3D in-world interaction prompt (e.g. Press E)." },
		{ name = "ClickDetector", base = "Instance", doc = "Detects mouse clicks and hovers on a 3D BasePart or Model." },
		{ name = "Sound", base = "Instance", doc = "Plays 2D or 3D positional audio." },
		{ name = "RemoteEvent", base = "Instance", doc = "Asynchronous two-way client/server network event." },
		{ name = "RemoteFunction", base = "Instance", doc = "Yielding two-way client/server RPC object." },
		{ name = "BindableEvent", base = "Instance", doc = "Same-side custom signal dispatcher." },
		{ name = "ObjectValue", base = "Instance", doc = "Holds a single Instance reference in .Value." },
		{ name = "StringValue", base = "Instance", doc = "Holds a string in .Value." },
		{ name = "NumberValue", base = "Instance", doc = "Holds a double-precision number in .Value." },
		{ name = "BoolValue", base = "Instance", doc = "Holds a boolean in .Value." },
	}

	-- Common Roblox Enums (`Enum.<Category>.<Item>`)
	M.enums = {
		KeyCode = { "Return", "Space", "Tab", "Escape", "Backspace", "LeftShift", "RightShift", "LeftControl", "LeftAlt", "E", "F", "Q", "R", "W", "A", "S", "D", "F1", "F2", "F5", "F11", "F12", "Up", "Down", "Left", "Right" },
		UserInputType = { "MouseButton1", "MouseButton2", "MouseMovement", "MouseWheel", "Touch", "Keyboard", "Gamepad1" },
		Font = { "Gotham", "GothamMedium", "GothamBold", "Code", "RobotoMono", "SourceSans", "BuilderSans" },
		EasingStyle = { "Linear", "Quad", "Cubic", "Quart", "Quint", "Sine", "Exponential", "Circular", "Back", "Bounce", "Elastic" },
		EasingDirection = { "In", "Out", "InOut" },
		FillDirection = { "Horizontal", "Vertical" },
		HorizontalAlignment = { "Left", "Center", "Right" },
		VerticalAlignment = { "Top", "Center", "Bottom" },
		TextXAlignment = { "Left", "Center", "Right" },
		TextYAlignment = { "Top", "Center", "Bottom" },
		Material = { "Plastic", "SmoothPlastic", "Neon", "ForceField", "Glass", "Metal", "Wood", "Slate", "Concrete" },
		RaycastFilterType = { "Exclude", "Include" },
	}

	-- Class Inheritance & Members (`access = "."` for properties/events, `access = ":"` for methods)
	M.classes = {
		Instance = {
			members = {
				{ name = "Name", kind = "property", access = ".", ret = "string", doc = "Non-unique identifier of this Instance." },
				{ name = "Parent", kind = "property", access = ".", ret = "Instance?", doc = "Hierarchical parent container of this Instance." },
				{ name = "ClassName", kind = "property", access = ".", ret = "string", doc = "Read-only runtime Roblox class name." },
				{ name = "Archivable", kind = "property", access = ".", ret = "boolean", doc = "Whether Clone() and serialization include this Instance." },
				{ name = "ChildAdded", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when a direct child is parented to this Instance." },
				{ name = "ChildRemoved", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when a direct child is removed from this Instance." },
				{ name = "Destroying", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires immediately before Destroy() tears down this Instance." },
				{ name = "FindFirstChild", kind = "method", access = ":", params = { "name: string", "recursive?: boolean" }, ret = "Instance?", insert = 'FindFirstChild("$0")', doc = "Returns the first child matching `name`, or nil if absent." },
				{ name = "FindFirstChildOfClass", kind = "method", access = ":", params = { "className: string" }, ret = "Instance?", insert = 'FindFirstChildOfClass("$0")', doc = "Returns the first direct child whose ClassName equals `className`." },
				{ name = "FindFirstChildWhichIsA", kind = "method", access = ":", params = { "className: string", "recursive?: boolean" }, ret = "Instance?", insert = 'FindFirstChildWhichIsA("$0")', doc = "Returns the first child respecting inheritance (`IsA(className)`)." },
				{ name = "FindFirstAncestorWhichIsA", kind = "method", access = ":", params = { "className: string" }, ret = "Instance?", insert = 'FindFirstAncestorWhichIsA("$0")', doc = "Walks up the Parent chain to find an ancestor matching `IsA(className)`." },
				{ name = "WaitForChild", kind = "method", access = ":", params = { "childName: string", "timeOut?: number" }, ret = "Instance?", insert = 'WaitForChild("$0")', doc = "Yields the current thread until a direct child named `childName` exists." },
				{ name = "GetChildren", kind = "method", access = ":", params = {}, ret = "{Instance}", insert = "GetChildren()", doc = "Returns an array of all direct child Instances." },
				{ name = "GetDescendants", kind = "method", access = ":", params = {}, ret = "{Instance}", insert = "GetDescendants()", doc = "Returns a flat array of every descendant in the subtree." },
				{ name = "IsA", kind = "method", access = ":", params = { "className: string" }, ret = "boolean", insert = 'IsA("$0")', doc = "Returns true if this Instance inherits from `className`." },
				{ name = "Clone", kind = "method", access = ":", params = {}, ret = "Instance", insert = "Clone()", doc = "Creates a deep copy of this Instance and its archivable descendants." },
				{ name = "Destroy", kind = "method", access = ":", params = {}, ret = "()", insert = "Destroy()", doc = "Locks Parent to nil, disconnects all connections, and destroys descendants." },
				{ name = "ClearAllChildren", kind = "method", access = ":", params = {}, ret = "()", insert = "ClearAllChildren()", doc = "Calls Destroy() on all direct children." },
				{ name = "GetAttribute", kind = "method", access = ":", params = { "attribute: string" }, ret = "any", insert = 'GetAttribute("$0")', doc = "Reads a custom attribute value assigned to this Instance." },
				{ name = "SetAttribute", kind = "method", access = ":", params = { "attribute: string", "value: any" }, ret = "()", insert = 'SetAttribute("$0", nil)', doc = "Assigns or clears a custom attribute on this Instance." },
				{ name = "GetPropertyChangedSignal", kind = "method", access = ":", params = { "property: string" }, ret = "RBXScriptSignal", insert = 'GetPropertyChangedSignal("$0")', doc = "Returns a signal that fires whenever the given property changes." },
				{ name = "GetFullName", kind = "method", access = ":", params = {}, ret = "string", insert = "GetFullName()", doc = "Returns the dot-separated ancestry path from DataModel." },
			},
		},
		DataModel = {
			base = "Instance",
			members = {
				{ name = "PlaceId", kind = "property", access = ".", ret = "number", doc = "Numeric Place ID of the running Roblox experience." },
				{ name = "JobId", kind = "property", access = ".", ret = "string", doc = "Unique UUID of the current game server instance." },
				{ name = "GameId", kind = "property", access = ".", ret = "number", doc = "Universe ID shared across all places in this experience." },
				{ name = "Workspace", kind = "property", access = ".", ret = "Workspace", doc = "Reference to the active 3D Workspace service." },
				{ name = "Players", kind = "property", access = ".", ret = "Players", doc = "Reference to the Players service." },
				{ name = "GetService", kind = "method", access = ":", params = { "serviceName: string" }, ret = "Instance", insert = 'GetService("$0")', doc = "Retrieves or initializes a singleton Roblox Engine service." },
				{ name = "HttpGet", kind = "method", access = ":", params = { "url: string" }, ret = "string", insert = 'HttpGet("$0")', doc = "Executor HTTP GET helper returning the response body as a string." },
				{ name = "IsLoaded", kind = "method", access = ":", params = {}, ret = "boolean", insert = "IsLoaded()", doc = "Returns true once initial replication has completed on the client." },
			},
		},
		Workspace = {
			base = "Instance",
			members = {
				{ name = "CurrentCamera", kind = "property", access = ".", ret = "Camera", doc = "Active client Camera rendering the 3D viewport." },
				{ name = "Gravity", kind = "property", access = ".", ret = "number", doc = "World downward acceleration in studs/second^2 (default 196.2)." },
				{ name = "Terrain", kind = "property", access = ".", ret = "Terrain", doc = "Voxel terrain instance." },
				{ name = "Raycast", kind = "method", access = ":", params = { "origin: Vector3", "direction: Vector3", "raycastParams?: RaycastParams" }, ret = "RaycastResult?", insert = "Raycast($0)", doc = "Casts a 3D ray from `origin` along `direction` and returns hit info." },
				{ name = "GetPartBoundsInBox", kind = "method", access = ":", params = { "cframe: CFrame", "size: Vector3", "overlapParams?: OverlapParams" }, ret = "{BasePart}", insert = "GetPartBoundsInBox($0)", doc = "Spatial query returning parts overlapping an oriented bounding box." },
				{ name = "GetPartBoundsInRadius", kind = "method", access = ":", params = { "position: Vector3", "radius: number", "overlapParams?: OverlapParams" }, ret = "{BasePart}", insert = "GetPartBoundsInRadius($0)", doc = "Spatial query returning parts within `radius` studs of `position`." },
				{ name = "GetServerTimeNow", kind = "method", access = ":", params = {}, ret = "number", insert = "GetServerTimeNow()", doc = "Returns synchronized server Unix timestamp with sub-millisecond precision." },
			},
		},
		Players = {
			base = "Instance",
			members = {
				{ name = "LocalPlayer", kind = "property", access = ".", ret = "Player", doc = "The client's own Player object (nil on the server)." },
				{ name = "MaxPlayers", kind = "property", access = ".", ret = "number", doc = "Maximum concurrent players allowed in this server." },
				{ name = "PlayerAdded", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when a player joins the server." },
				{ name = "PlayerRemoving", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires right before a player disconnects from the server." },
				{ name = "GetPlayers", kind = "method", access = ":", params = {}, ret = "{Player}", insert = "GetPlayers()", doc = "Returns an array of all currently connected Player objects." },
				{ name = "GetPlayerFromCharacter", kind = "method", access = ":", params = { "character: Model" }, ret = "Player?", insert = "GetPlayerFromCharacter($0)", doc = "Finds the Player whose Character matches `character`." },
				{ name = "GetPlayerByUserId", kind = "method", access = ":", params = { "userId: number" }, ret = "Player?", insert = "GetPlayerByUserId($0)", doc = "Finds a connected Player by numeric Roblox UserId." },
			},
		},
		Player = {
			base = "Instance",
			members = {
				{ name = "DisplayName", kind = "property", access = ".", ret = "string", doc = "User-chosen non-unique display name." },
				{ name = "UserId", kind = "property", access = ".", ret = "number", doc = "Permanent numeric Roblox account ID." },
				{ name = "Character", kind = "property", access = ".", ret = "Model?", doc = "Currently spawned 3D avatar Model in Workspace." },
				{ name = "PlayerGui", kind = "property", access = ".", ret = "Instance", doc = "Container holding the player's local ScreenGuis." },
				{ name = "Backpack", kind = "property", access = ".", ret = "Instance", doc = "Container holding unequipped Tool instances." },
				{ name = "Team", kind = "property", access = ".", ret = "Instance?", doc = "Assigned Team object, if any." },
				{ name = "CharacterAdded", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires each time the player's Character spawns." },
				{ name = "CharacterRemoving", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires right before the player's Character is removed." },
				{ name = "Kick", kind = "method", access = ":", params = { "message?: string" }, ret = "()", insert = 'Kick("$0")', doc = "Disconnects the player with an optional message." },
				{ name = "GetMouse", kind = "method", access = ":", params = {}, ret = "Instance", insert = "GetMouse()", doc = "Returns the legacy PlayerMouse object." },
				{ name = "DistanceFromCharacter", kind = "method", access = ":", params = { "point: Vector3" }, ret = "number", insert = "DistanceFromCharacter($0)", doc = "Returns distance in studs between the player's head/root and `point`." },
			},
		},
		BasePart = {
			base = "Instance",
			members = {
				{ name = "Position", kind = "property", access = ".", ret = "Vector3", doc = "World-space 3D position of the part center." },
				{ name = "Size", kind = "property", access = ".", ret = "Vector3", doc = "Dimensions (X, Y, Z) of the part in studs." },
				{ name = "CFrame", kind = "property", access = ".", ret = "CFrame", doc = "World-space 3D position and rotation matrix." },
				{ name = "Anchored", kind = "property", access = ".", ret = "boolean", doc = "If true, physics gravity and forces will not move this part." },
				{ name = "CanCollide", kind = "property", access = ".", ret = "boolean", doc = "Whether physical collisions occur against other parts." },
				{ name = "CanQuery", kind = "property", access = ".", ret = "boolean", doc = "Whether Raycast and spatial queries can hit this part." },
				{ name = "Transparency", kind = "property", access = ".", ret = "number", doc = "Visual opacity from 0 (opaque) to 1 (invisible)." },
				{ name = "Color", kind = "property", access = ".", ret = "Color3", doc = "RGB surface tint Color3." },
				{ name = "Material", kind = "property", access = ".", ret = "Enum.Material", doc = "Surface physical and visual material." },
				{ name = "AssemblyLinearVelocity", kind = "property", access = ".", ret = "Vector3", doc = "Linear velocity vector of the rigid assembly." },
				{ name = "Touched", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when another physically simulated part collides with this part." },
				{ name = "TouchEnded", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when physical contact ends." },
				{ name = "PivotTo", kind = "method", access = ":", params = { "targetCFrame: CFrame" }, ret = "()", insert = "PivotTo($0)", doc = "Moves the part or assembly so its pivot matches `targetCFrame`." },
				{ name = "ApplyImpulse", kind = "method", access = ":", params = { "impulse: Vector3" }, ret = "()", insert = "ApplyImpulse($0)", doc = "Applies an instantaneous physics impulse vector." },
			},
		},
		Part = { base = "BasePart", members = {} },
		Humanoid = {
			base = "Instance",
			members = {
				{ name = "Health", kind = "property", access = ".", ret = "number", doc = "Current health points of the character." },
				{ name = "MaxHealth", kind = "property", access = ".", ret = "number", doc = "Maximum health capacity." },
				{ name = "WalkSpeed", kind = "property", access = ".", ret = "number", doc = "Movement speed in studs/second (default 16)." },
				{ name = "JumpPower", kind = "property", access = ".", ret = "number", doc = "Upward jump impulse power (default 50)." },
				{ name = "JumpHeight", kind = "property", access = ".", ret = "number", doc = "Target jump apex height in studs (default 7.2)." },
				{ name = "MoveDirection", kind = "property", access = ".", ret = "Vector3", doc = "World-space unit vector of character movement input." },
				{ name = "RootPart", kind = "property", access = ".", ret = "BasePart?", doc = "Reference to HumanoidRootPart." },
				{ name = "Died", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when Health reaches 0." },
				{ name = "HealthChanged", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires whenever Health changes." },
				{ name = "TakeDamage", kind = "method", access = ":", params = { "amount: number" }, ret = "()", insert = "TakeDamage($0)", doc = "Subtracts `amount` health while respecting ForceFields." },
				{ name = "MoveTo", kind = "method", access = ":", params = { "location: Vector3", "part?: BasePart" }, ret = "()", insert = "MoveTo($0)", doc = "Commands the Humanoid to walk toward `location`." },
			},
		},
		RunService = {
			base = "Instance",
			members = {
				{ name = "Heartbeat", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires every frame after physics simulation (`dt: number`)." },
				{ name = "RenderStepped", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Client-only signal firing every frame prior to rendering (`dt: number`)." },
				{ name = "Stepped", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires every frame prior to physics (`time: number, dt: number`)." },
				{ name = "IsClient", kind = "method", access = ":", params = {}, ret = "boolean", insert = "IsClient()", doc = "Returns true when running on a Roblox client." },
				{ name = "IsServer", kind = "method", access = ":", params = {}, ret = "boolean", insert = "IsServer()", doc = "Returns true when running on a Roblox server." },
				{ name = "IsStudio", kind = "method", access = ":", params = {}, ret = "boolean", insert = "IsStudio()", doc = "Returns true inside Roblox Studio." },
				{ name = "BindToRenderStep", kind = "method", access = ":", params = { "name: string", "priority: number", "callback: (dt: number) -> ()" }, ret = "()", insert = 'BindToRenderStep("$0", 200, function(dt)\n\t\nend)', doc = "Registers a named render-step callback at a specific priority." },
				{ name = "UnbindFromRenderStep", kind = "method", access = ":", params = { "name: string" }, ret = "()", insert = 'UnbindFromRenderStep("$0")', doc = "Removes a callback previously registered via BindToRenderStep." },
			},
		},
		UserInputService = {
			base = "Instance",
			members = {
				{ name = "TouchEnabled", kind = "property", access = ".", ret = "boolean", doc = "True if the current device has a touchscreen." },
				{ name = "KeyboardEnabled", kind = "property", access = ".", ret = "boolean", doc = "True if a hardware keyboard is connected." },
				{ name = "MouseEnabled", kind = "property", access = ".", ret = "boolean", doc = "True if a mouse/trackpad is available." },
				{ name = "InputBegan", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when a key, button, or touch begins (`input, gameProcessed`)." },
				{ name = "InputChanged", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when pointer/touch/wheel input updates." },
				{ name = "InputEnded", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when a key, button, or touch ends." },
				{ name = "IsKeyDown", kind = "method", access = ":", params = { "keyCode: Enum.KeyCode" }, ret = "boolean", insert = "IsKeyDown(Enum.KeyCode.$0)", doc = "Returns true while `keyCode` is physically held down." },
				{ name = "GetMouseLocation", kind = "method", access = ":", params = {}, ret = "Vector2", insert = "GetMouseLocation()", doc = "Returns screen-space 2D cursor coordinates." },
				{ name = "GetFocusedTextBox", kind = "method", access = ":", params = {}, ret = "TextBox?", insert = "GetFocusedTextBox()", doc = "Returns the currently focused TextBox, or nil." },
			},
		},
		TweenService = {
			base = "Instance",
			members = {
				{ name = "Create", kind = "method", access = ":", params = { "instance: Instance", "tweenInfo: TweenInfo", "propertyTable: {[string]: any}" }, ret = "Tween", insert = "Create($0)", doc = "Creates an animatable Tween for `instance` properties." },
				{ name = "GetValue", kind = "method", access = ":", params = { "alpha: number", "easingStyle: Enum.EasingStyle", "easingDirection: Enum.EasingDirection" }, ret = "number", insert = "GetValue($0)", doc = "Evaluates an easing curve at `alpha` in [0, 1]." },
			},
		},
		HttpService = {
			base = "Instance",
			members = {
				{ name = "JSONEncode", kind = "method", access = ":", params = { "value: any" }, ret = "string", insert = "JSONEncode($0)", doc = "Serializes a Luau table or primitive into a JSON string." },
				{ name = "JSONDecode", kind = "method", access = ":", params = { "json: string" }, ret = "any", insert = "JSONDecode($0)", doc = "Parses a JSON string into a Luau value." },
				{ name = "GenerateGUID", kind = "method", access = ":", params = { "wrapInCurlyBraces?: boolean" }, ret = "string", insert = "GenerateGUID(false)", doc = "Generates a random UUID v4 string." },
				{ name = "UrlEncode", kind = "method", access = ":", params = { "input: string" }, ret = "string", insert = "UrlEncode($0)", doc = "Percent-encodes special URL characters." },
			},
		},
		GuiObject = {
			base = "Instance",
			members = {
				{ name = "Size", kind = "property", access = ".", ret = "UDim2", doc = "2D scale and pixel offset size." },
				{ name = "Position", kind = "property", access = ".", ret = "UDim2", doc = "2D scale and pixel offset position." },
				{ name = "AnchorPoint", kind = "property", access = ".", ret = "Vector2", doc = "Normalized origin point in [0, 1] x [0, 1]." },
				{ name = "AbsoluteSize", kind = "property", access = ".", ret = "Vector2", doc = "Read-only resolved pixel dimensions." },
				{ name = "AbsolutePosition", kind = "property", access = ".", ret = "Vector2", doc = "Read-only resolved screen pixel position." },
				{ name = "BackgroundColor3", kind = "property", access = ".", ret = "Color3", doc = "Fill background color." },
				{ name = "BackgroundTransparency", kind = "property", access = ".", ret = "number", doc = "Fill transparency from 0 (opaque) to 1 (hidden)." },
				{ name = "Visible", kind = "property", access = ".", ret = "boolean", doc = "Whether this GuiObject and its descendants render." },
				{ name = "ZIndex", kind = "property", access = ".", ret = "number", doc = "Draw stacking order." },
				{ name = "LayoutOrder", kind = "property", access = ".", ret = "number", doc = "Sort order when inside UIListLayout or UIGridLayout." },
				{ name = "ClipsDescendants", kind = "property", access = ".", ret = "boolean", doc = "Clips child rendering to this GuiObject's rectangle." },
				{ name = "Active", kind = "property", access = ".", ret = "boolean", doc = "Whether pointer input is sunk by this GuiObject." },
				{ name = "InputBegan", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when pointer/touch begins inside this GuiObject." },
				{ name = "MouseEnter", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when the mouse cursor enters this GuiObject." },
				{ name = "MouseLeave", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when the mouse cursor leaves this GuiObject." },
			},
		},
		Frame = { base = "GuiObject", members = {} },
		ScrollingFrame = {
			base = "GuiObject",
			members = {
				{ name = "CanvasSize", kind = "property", access = ".", ret = "UDim2", doc = "Total scrollable virtual area size." },
				{ name = "CanvasPosition", kind = "property", access = ".", ret = "Vector2", doc = "Current pixel scroll offset." },
				{ name = "AutomaticCanvasSize", kind = "property", access = ".", ret = "Enum.AutomaticSize", doc = "Automatically expands CanvasSize to fit children." },
				{ name = "ScrollBarThickness", kind = "property", access = ".", ret = "number", doc = "Thickness of scrollbars in pixels." },
			},
		},
		TextLabel = {
			base = "GuiObject",
			members = {
				{ name = "Text", kind = "property", access = ".", ret = "string", doc = "Displayed string content." },
				{ name = "TextColor3", kind = "property", access = ".", ret = "Color3", doc = "RGB text color." },
				{ name = "TextSize", kind = "property", access = ".", ret = "number", doc = "Font point height." },
				{ name = "Font", kind = "property", access = ".", ret = "Enum.Font", doc = "Typography font enum." },
				{ name = "RichText", kind = "property", access = ".", ret = "boolean", doc = "Enables inline HTML-like formatting tags." },
				{ name = "TextWrapped", kind = "property", access = ".", ret = "boolean", doc = "Wraps long lines within horizontal bounds." },
			},
		},
		TextButton = {
			base = "TextLabel",
			members = {
				{ name = "AutoButtonColor", kind = "property", access = ".", ret = "boolean", doc = "Automatically darkens background on hover/press." },
				{ name = "Activated", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Cross-platform click/tap activation signal." },
				{ name = "MouseButton1Click", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires on primary mouse click." },
			},
		},
		TextBox = {
			base = "TextLabel",
			members = {
				{ name = "PlaceholderText", kind = "property", access = ".", ret = "string", doc = "Hint text displayed when Text is empty." },
				{ name = "ClearTextOnFocus", kind = "property", access = ".", ret = "boolean", doc = "Whether focusing clears existing Text." },
				{ name = "TextEditable", kind = "property", access = ".", ret = "boolean", doc = "Allows or prevents user text editing." },
				{ name = "CursorPosition", kind = "property", access = ".", ret = "number", doc = "1-based caret index inside Text." },
				{ name = "Focused", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when the user focuses the TextBox." },
				{ name = "FocusLost", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when focus leaves (`enterPressed: boolean`)." },
				{ name = "CaptureFocus", kind = "method", access = ":", params = {}, ret = "()", insert = "CaptureFocus()", doc = "Programmatically focuses the TextBox." },
				{ name = "ReleaseFocus", kind = "method", access = ":", params = { "submitted?: boolean" }, ret = "()", insert = "ReleaseFocus()", doc = "Programmatically unfocuses the TextBox." },
			},
		},
		RBXScriptSignal = {
			members = {
				{ name = "Connect", kind = "method", access = ":", params = { "callback: (...any) -> ()" }, ret = "RBXScriptConnection", insert = "Connect(function($0)\n\t\nend)", doc = "Subscribes `callback` to run every time this signal fires." },
				{ name = "Once", kind = "method", access = ":", params = { "callback: (...any) -> ()" }, ret = "RBXScriptConnection", insert = "Once(function($0)\n\t\nend)", doc = "Subscribes `callback` for a single firing, then auto-disconnects." },
				{ name = "Wait", kind = "method", access = ":", params = {}, ret = "...any", insert = "Wait()", doc = "Yields the current coroutine until the next time this signal fires." },
			},
		},
		Tween = {
			members = {
				{ name = "Completed", kind = "event", access = ".", ret = "RBXScriptSignal", doc = "Fires when the Tween finishes or is cancelled." },
				{ name = "Play", kind = "method", access = ":", params = {}, ret = "()", insert = "Play()", doc = "Starts or resumes the property interpolation." },
				{ name = "Pause", kind = "method", access = ":", params = {}, ret = "()", insert = "Pause()", doc = "Pauses the Tween at its current progress." },
				{ name = "Cancel", kind = "method", access = ":", params = {}, ret = "()", insert = "Cancel()", doc = "Stops the Tween and resets playback state." },
			},
		},
	}

	-- Luau & Roblox Global Libraries (`task.*`, `Instance.*`, `UDim2.*`, `Color3.*`, `Vector3.*`, `CFrame.*`, `math.*`, `string.*`, `table.*`)
	M.libraries = {
		Instance = {
			{ name = "new", kind = "constructor", params = { "className: string", "parent?: Instance" }, ret = "Instance", insert = 'new("$0")', doc = "Constructs a new Roblox Instance of `className`." },
			{ name = "fromExisting", kind = "constructor", params = { "existing: Instance" }, ret = "Instance", insert = "fromExisting($0)", doc = "Creates a shallow copy sharing geometry/configuration of `existing`." },
		},
		task = {
			{ name = "spawn", kind = "function", params = { "fnOrThread: ((...any) -> ()) | thread", "...: any" }, ret = "thread", insert = "spawn(function()\n\t$0\nend)", doc = "Immediately resumes a function or coroutine via the Roblox scheduler." },
			{ name = "defer", kind = "function", params = { "fnOrThread: ((...any) -> ()) | thread", "...: any" }, ret = "thread", insert = "defer(function()\n\t$0\nend)", doc = "Schedules a function to run at the end of the current resumption cycle." },
			{ name = "delay", kind = "function", params = { "duration: number", "fnOrThread: ((...any) -> ()) | thread", "...: any" }, ret = "thread", insert = "delay($0, function()\n\t\nend)", doc = "Schedules a function to execute after `duration` seconds." },
			{ name = "wait", kind = "function", params = { "duration?: number" }, ret = "number", insert = "wait($0)", doc = "Yields the current coroutine for `duration` seconds (or 1 Heartbeat) and returns elapsed time." },
			{ name = "cancel", kind = "function", params = { "thread: thread" }, ret = "()", insert = "cancel($0)", doc = "Cancels a scheduled or yielded coroutine." },
		},
		UDim2 = {
			{ name = "new", kind = "constructor", params = { "xScale: number", "xOffset: number", "yScale: number", "yOffset: number" }, ret = "UDim2", insert = "new($0)", doc = "Constructs a UDim2 from X/Y scale and offset components." },
			{ name = "fromOffset", kind = "constructor", params = { "xOffset: number", "yOffset: number" }, ret = "UDim2", insert = "fromOffset($0)", doc = "Constructs a pixel-offset UDim2 (`scale = 0`)." },
			{ name = "fromScale", kind = "constructor", params = { "xScale: number", "yScale: number" }, ret = "UDim2", insert = "fromScale($0)", doc = "Constructs a normalized scale UDim2 (`offset = 0`)." },
		},
		Color3 = {
			{ name = "fromRGB", kind = "constructor", params = { "r: number", "g: number", "b: number" }, ret = "Color3", insert = "fromRGB($0)", doc = "Creates a Color3 from integer RGB components in [0, 255]." },
			{ name = "fromHSV", kind = "constructor", params = { "h: number", "s: number", "v: number" }, ret = "Color3", insert = "fromHSV($0)", doc = "Creates a Color3 from normalized Hue, Saturation, Value in [0, 1]." },
			{ name = "fromHex", kind = "constructor", params = { "hex: string" }, ret = "Color3", insert = 'fromHex("#$0")', doc = "Parses a 6-digit `#RRGGBB` hex color string." },
			{ name = "new", kind = "constructor", params = { "r: number", "g: number", "b: number" }, ret = "Color3", insert = "new($0)", doc = "Creates a Color3 from normalized float RGB components in [0, 1]." },
		},
		Vector2 = {
			{ name = "new", kind = "constructor", params = { "x?: number", "y?: number" }, ret = "Vector2", insert = "new($0)", doc = "Constructs a 2D vector (X, Y)." },
			{ name = "zero", kind = "property", ret = "Vector2", doc = "Constant Vector2(0, 0)." },
			{ name = "one", kind = "property", ret = "Vector2", doc = "Constant Vector2(1, 1)." },
		},
		Vector3 = {
			{ name = "new", kind = "constructor", params = { "x?: number", "y?: number", "z?: number" }, ret = "Vector3", insert = "new($0)", doc = "Constructs a 3D vector (X, Y, Z)." },
			{ name = "zero", kind = "property", ret = "Vector3", doc = "Constant Vector3(0, 0, 0)." },
			{ name = "one", kind = "property", ret = "Vector3", doc = "Constant Vector3(1, 1, 1)." },
			{ name = "yAxis", kind = "property", ret = "Vector3", doc = "Constant unit upward vector Vector3(0, 1, 0)." },
		},
		CFrame = {
			{ name = "new", kind = "constructor", params = { "pos: Vector3", "lookAt?: Vector3" }, ret = "CFrame", insert = "new($0)", doc = "Constructs a 3D Coordinate Frame." },
			{ name = "lookAt", kind = "constructor", params = { "at: Vector3", "lookAt: Vector3", "up?: Vector3" }, ret = "CFrame", insert = "lookAt($0)", doc = "Constructs a CFrame at `at` oriented toward `lookAt`." },
			{ name = "Angles", kind = "constructor", params = { "rx: number", "ry: number", "rz: number" }, ret = "CFrame", insert = "Angles($0)", doc = "Constructs a rotation CFrame from Euler angles in radians." },
			{ name = "identity", kind = "property", ret = "CFrame", doc = "Identity CFrame at origin with zero rotation." },
		},
		TweenInfo = {
			{ name = "new", kind = "constructor", params = { "time?: number", "easingStyle?: Enum.EasingStyle", "easingDirection?: Enum.EasingDirection", "repeatCount?: number", "reverses?: boolean", "delayTime?: number" }, ret = "TweenInfo", insert = "new($0)", doc = "Constructs timing and easing parameters for TweenService:Create." },
		},
		RaycastParams = {
			{ name = "new", kind = "constructor", params = {}, ret = "RaycastParams", insert = "new()", doc = "Constructs filter parameters for workspace:Raycast." },
		},
		string = {
			{ name = "format", kind = "function", params = { "formatString: string", "...: any" }, ret = "string", insert = 'format("$0")', doc = "Formats values according to printf-style specifiers." },
			{ name = "find", kind = "function", params = { "s: string", "pattern: string", "init?: number", "plain?: boolean" }, ret = "(number?, number?)", insert = "find($0)", doc = "Finds the first match of `pattern` in `s`." },
			{ name = "match", kind = "function", params = { "s: string", "pattern: string", "init?: number" }, ret = "...string", insert = "match($0)", doc = "Extracts captures matching `pattern` from `s`." },
			{ name = "gmatch", kind = "function", params = { "s: string", "pattern: string" }, ret = "() -> ...string", insert = "gmatch($0)", doc = "Returns an iterator over all matches of `pattern` in `s`." },
			{ name = "gsub", kind = "function", params = { "s: string", "pattern: string", "repl: string | table | function", "n?: number" }, ret = "(string, number)", insert = "gsub($0)", doc = "Substitutes matches of `pattern` in `s`." },
			{ name = "sub", kind = "function", params = { "s: string", "i: number", "j?: number" }, ret = "string", insert = "sub($0)", doc = "Returns the substring of `s` from `i` to `j`." },
			{ name = "split", kind = "function", params = { "s: string", "separator?: string" }, ret = "{string}", insert = 'split($0, ",")', doc = "Splits `s` on `separator` into an array of strings." },
			{ name = "lower", kind = "function", params = { "s: string" }, ret = "string", insert = "lower($0)", doc = "Converts ASCII uppercase letters to lowercase." },
			{ name = "upper", kind = "function", params = { "s: string" }, ret = "string", insert = "upper($0)", doc = "Converts ASCII lowercase letters to uppercase." },
			{ name = "rep", kind = "function", params = { "s: string", "n: number" }, ret = "string", insert = "rep($0)", doc = "Repeats string `s` `n` times." },
		},
		table = {
			{ name = "insert", kind = "function", params = { "list: {T}", "posOrValue: number | T", "value?: T" }, ret = "()", insert = "insert($0)", doc = "Appends or inserts an element into array `list`." },
			{ name = "remove", kind = "function", params = { "list: {T}", "pos?: number" }, ret = "T?", insert = "remove($0)", doc = "Removes and returns the element at `pos` (default `#list`)." },
			{ name = "concat", kind = "function", params = { "list: {string}", "sep?: string", "i?: number", "j?: number" }, ret = "string", insert = 'concat($0, "\\n")', doc = "Joins array strings separated by `sep`." },
			{ name = "sort", kind = "function", params = { "list: {T}", "comp?: (a: T, b: T) -> boolean" }, ret = "()", insert = "sort($0)", doc = "Sorts array `list` in-place." },
			{ name = "find", kind = "function", params = { "haystack: {T}", "needle: T", "init?: number" }, ret = "number?", insert = "find($0)", doc = "Returns the 1-based index of `needle` in `haystack`, or nil." },
			{ name = "clear", kind = "function", params = { "t: table" }, ret = "()", insert = "clear($0)", doc = "Removes all keys from `t` while keeping allocated capacity." },
			{ name = "clone", kind = "function", params = { "t: table" }, ret = "table", insert = "clone($0)", doc = "Returns a shallow copy of table `t`." },
		},
		math = {
			{ name = "clamp", kind = "function", params = { "x: number", "min: number", "max: number" }, ret = "number", insert = "clamp($0)", doc = "Clamps `x` to the inclusive range `[min, max]`." },
			{ name = "floor", kind = "function", params = { "x: number" }, ret = "number", insert = "floor($0)", doc = "Rounds `x` down to the nearest integer." },
			{ name = "ceil", kind = "function", params = { "x: number" }, ret = "number", insert = "ceil($0)", doc = "Rounds `x` up to the nearest integer." },
			{ name = "round", kind = "function", params = { "x: number" }, ret = "number", insert = "round($0)", doc = "Rounds `x` to the nearest integer." },
			{ name = "abs", kind = "function", params = { "x: number" }, ret = "number", insert = "abs($0)", doc = "Returns absolute value `|x|`." },
			{ name = "min", kind = "function", params = { "x: number", "...: number" }, ret = "number", insert = "min($0)", doc = "Returns the smallest argument." },
			{ name = "max", kind = "function", params = { "x: number", "...: number" }, ret = "number", insert = "max($0)", doc = "Returns the largest argument." },
			{ name = "lerp", kind = "function", params = { "a: number", "b: number", "t: number" }, ret = "number", insert = "lerp($0)", doc = "Linearly interpolates between `a` and `b` by `t`." },
			{ name = "random", kind = "function", params = { "m?: number", "n?: number" }, ret = "number", insert = "random($0)", doc = "Generates a pseudo-random float or integer." },
		},
	}

	-- Global Functions & Executor APIs (with full signature & hover docs)
	M.globals = {
		print = { kind = "builtin", params = { "...: any" }, ret = "()", doc = "Prints formatted values to the Roblox Output console." },
		warn = { kind = "builtin", params = { "...: any" }, ret = "()", doc = "Emits a yellow warning message to the Roblox Output console." },
		error = { kind = "builtin", params = { "message: any", "level?: number" }, ret = "never", doc = "Raises a runtime Luau error at stack `level`." },
		assert = { kind = "builtin", params = { "value: T", "message?: string" }, ret = "T", doc = "Errors with `message` if `value` is falsy, otherwise returns `value`." },
		pcall = { kind = "builtin", params = { "fn: (...any) -> ...any", "...: any" }, ret = "(boolean, ...any)", doc = "Calls `fn` in protected mode, catching any runtime error." },
		xpcall = { kind = "builtin", params = { "fn: (...any) -> ...any", "errHandler: (err: any) -> any", "...: any" }, ret = "(boolean, ...any)", doc = "Calls `fn` in protected mode with a custom error handler." },
		require = { kind = "builtin", params = { "module: ModuleScript | string" }, ret = "any", insert = 'require("$0")', doc = "Loads and caches a workspace module or Roblox ModuleScript." },
		typeof = { kind = "builtin", params = { "value: any" }, ret = "string", doc = "Returns the Roblox-aware runtime type string (e.g. 'Instance', 'Vector3')." },
		tonumber = { kind = "builtin", params = { "value: any", "base?: number" }, ret = "number?", doc = "Parses `value` into a number, or nil on failure." },
		tostring = { kind = "builtin", params = { "value: any" }, ret = "string", doc = "Converts `value` to its string representation." },
		ipairs = { kind = "builtin", params = { "list: {T}" }, ret = "iterator", doc = "Iterates integer keys `1..#list` in order." },
		pairs = { kind = "builtin", params = { "t: table" }, ret = "iterator", doc = "Iterates all key-value pairs in table `t`." },
		select = { kind = "builtin", params = { "index: number | '#'", "...: any" }, ret = "...any", doc = "Returns varargs starting at `index`, or count when `'#'`." },

		-- Executor APIs
		readfile = { kind = "executor", params = { "path: string" }, ret = "string", insert = 'readfile("$0")', doc = "Executor FS: Reads file contents from the local executor workspace folder." },
		writefile = { kind = "executor", params = { "path: string", "content: string" }, ret = "()", insert = 'writefile("$0", "")', doc = "Executor FS: Writes `content` to `path` inside the local executor workspace." },
		appendfile = { kind = "executor", params = { "path: string", "content: string" }, ret = "()", insert = 'appendfile("$0", "")', doc = "Executor FS: Appends `content` to an existing file on disk." },
		listfiles = { kind = "executor", params = { "folder: string" }, ret = "{string}", insert = 'listfiles("$0")', doc = "Executor FS: Lists file and folder paths inside `folder`." },
		makefolder = { kind = "executor", params = { "path: string" }, ret = "()", insert = 'makefolder("$0")', doc = "Executor FS: Creates directory `path` on local disk." },
		delfile = { kind = "executor", params = { "path: string" }, ret = "()", insert = 'delfile("$0")', doc = "Executor FS: Deletes file `path` from local disk." },
		delfolder = { kind = "executor", params = { "path: string" }, ret = "()", insert = 'delfolder("$0")', doc = "Executor FS: Deletes directory `path` from local disk." },
		isfile = { kind = "executor", params = { "path: string" }, ret = "boolean", insert = 'isfile("$0")', doc = "Executor FS: Returns true if `path` exists as a file." },
		isfolder = { kind = "executor", params = { "path: string" }, ret = "boolean", insert = 'isfolder("$0")', doc = "Executor FS: Returns true if `path` exists as a folder." },
		request = { kind = "executor", params = { "options: { Url: string, Method?: string, Headers?: {[string]: string}, Body?: string }" }, ret = "{ StatusCode: number, Body: string, Headers: table }", insert = 'request({ Url = "$0", Method = "GET" })', doc = "Executor HTTP: Performs an arbitrary HTTP/HTTPS request." },
		loadstring = { kind = "executor", params = { "source: string", "chunkName?: string" }, ret = "((...any) -> ...any)?, string?", insert = 'loadstring("$0")()', doc = "Compiles Luau source text into an executable chunk at runtime." },
		getgenv = { kind = "executor", params = {}, ret = "{[string]: any}", insert = "getgenv()", doc = "Returns the shared global executor environment table across scripts." },
		setclipboard = { kind = "executor", params = { "text: string" }, ret = "()", insert = "setclipboard($0)", doc = "Copies `text` to the host OS clipboard." },
		decompile = { kind = "executor", params = { "scriptInstance: LuaSourceContainer" }, ret = "string", insert = "decompile($0)", doc = "Decompiles a LocalScript or ModuleScript bytecode into readable Luau." },
		getconnections = { kind = "executor", params = { "signal: RBXScriptSignal" }, ret = "{Connection}", insert = "getconnections($0)", doc = "Returns active Luau connections attached to `signal`." },
		hookfunction = { kind = "executor", params = { "target: function", "hook: function" }, ret = "function", insert = "hookfunction($0)", doc = "Redirects calls to `target` through `hook` and returns the original function." },
	}

	-- Rich Expandable Snippets (`$0` marks caret placement)
	M.snippets = {
		luau = {
			{ trigger = "service", label = "GetService local binding", insert = 'local $0 = game:GetService("Players")', doc = "Imports a Roblox Engine service into a local variable." },
			{ trigger = "players", label = "Players + LocalPlayer boilerplate", insert = 'local Players = game:GetService("Players")\nlocal LocalPlayer = Players.LocalPlayer\n$0', doc = "Binds Players service and LocalPlayer." },
			{ trigger = "conn", label = "Signal :Connect(...) block", insert = ":Connect(function($0)\n\t\nend)", doc = "Connects an event listener function." },
			{ trigger = "tween", label = "TweenService:Create & Play", insert = 'local TweenService = game:GetService("TweenService")\nlocal tween = TweenService:Create($0, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {})\ntween:Play()', doc = "Creates and plays a smooth Tween." },
			{ trigger = "pcall", label = "Protected pcall(...) guard", insert = "local ok, res = pcall(function()\n\treturn $0\nend)\nif not ok then\n\twarn(res)\nend", doc = "Wraps risky logic in a protected pcall with warning log." },
			{ trigger = "module", label = "Module table scaffold", insert = "local M = {}\n\nfunction M.init($0)\n\t\nend\n\nreturn M", doc = "Creates a clean reusable Luau module table." },
			{ trigger = "class", label = "Metatable OOP class", insert = "local Class = {}\nClass.__index = Class\n\nfunction Class.new($0)\n\tlocal self = setmetatable({}, Class)\n\treturn self\nend\n\nreturn Class", doc = "Creates an idiomatic Luau metatable OOP class." },
			{ trigger = "raycast", label = "workspace:Raycast boilerplate", insert = "local params = RaycastParams.new()\nparams.FilterType = Enum.RaycastFilterType.Exclude\nparams.FilterDescendantsInstances = { $0 }\nlocal hit = workspace:Raycast(origin, direction, params)", doc = "Sets up RaycastParams and casts a 3D ray." },
			{ trigger = "taskspawn", label = "task.spawn async block", insert = "task.spawn(function()\n\t$0\nend)", doc = "Spawns an asynchronous coroutine via task.spawn." },
		},
		typescript = {
			{ trigger = "iface", label = "interface declaration", insert = "export interface $0 {\n\tid: string;\n}", doc = "TypeScript exported interface." },
			{ trigger = "afn", label = "async arrow function", insert = "const fn = async ($0): Promise<void> => {\n\t\n};", doc = "Async typed arrow function." },
		},
		python = {
			{ trigger = "defm", label = "def main() entrypoint", insert = "def main():\n    $0\n\nif __name__ == \"__main__\":\n    main()", doc = "Python script entrypoint." },
			{ trigger = "dclass", label = "@dataclass model", insert = "from dataclasses import dataclass\n\n@dataclass\nclass Model:\n    $0", doc = "Python dataclass boilerplate." },
		},
	}

	-- Resolve full inherited member list for a Roblox class
	function M.membersOfClass(className)
		local out = {}
		local seen = {}
		local cur = className
		local guard = 0
		while cur and M.classes[cur] and guard < 10 do
			guard = guard + 1
			local cls = M.classes[cur]
			for _, m in ipairs(cls.members or {}) do
				if not seen[m.name] then
					seen[m.name] = true
					out[#out + 1] = m
				end
			end
			cur = cls.base
		end
		-- Any unknown Roblox Instance class still inherits `Instance` members!
		if #out == 0 and className and className ~= "" then
			for _, m in ipairs(M.classes.Instance.members) do
				out[#out + 1] = m
			end
		end
		return out
	end

	function M.findClassMember(className, memberName)
		for _, m in ipairs(M.membersOfClass(className)) do
			if m.name == memberName then
				return m
			end
		end
		return nil
	end

	return M
end
