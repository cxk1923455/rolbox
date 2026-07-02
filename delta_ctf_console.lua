local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local GUI_NAME = "DeltaCTFConsole"
local FOV_GUI_NAME = GUI_NAME .. "_FOV"
local REMOTE_LOG_LIMIT = 180
local EXPANDED_MAIN_SIZE = Vector2.new(1120, 700)
local COLLAPSED_MAIN_SIZE = Vector2.new(440, 86)
local TOUCH_EXPANDED_MAIN_SIZE = Vector2.new(960, 600)
local TOUCH_COLLAPSED_MAIN_SIZE = Vector2.new(360, 72)
local PHONE_EXPANDED_MAIN_SIZE = Vector2.new(820, 520)
local PHONE_COLLAPSED_MAIN_SIZE = Vector2.new(300, 62)

local theme = {
    bg = Color3.fromRGB(11, 14, 20),
    panel = Color3.fromRGB(18, 22, 30),
    panelAlt = Color3.fromRGB(23, 29, 40),
    row = Color3.fromRGB(25, 32, 44),
    rowAlt = Color3.fromRGB(31, 39, 54),
    stroke = Color3.fromRGB(55, 68, 93),
    text = Color3.fromRGB(236, 241, 248),
    subtext = Color3.fromRGB(143, 159, 182),
    accent = Color3.fromRGB(74, 186, 255),
    accentAlt = Color3.fromRGB(224, 70, 255),
    success = Color3.fromRGB(93, 220, 137),
    warn = Color3.fromRGB(255, 196, 78),
    danger = Color3.fromRGB(255, 108, 108),
    npc = Color3.fromRGB(65, 195, 255),
    container = Color3.fromRGB(255, 201, 79),
    prompt = Color3.fromRGB(255, 86, 196),
    player = Color3.fromRGB(255, 110, 110)
}

local function pickGuiParent()
    if gethui then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end
    return CoreGui
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoidRootPart(model)
    if not model then
        return nil
    end
    if model:IsA("BasePart") then
        return model
    end
    if model:IsA("Attachment") then
        return model.Parent
    end
    if model:IsA("Model") then
        return model.PrimaryPart
            or model:FindFirstChild("HumanoidRootPart", true)
            or model:FindFirstChildWhichIsA("BasePart", true)
    end
    if model.Parent then
        return getHumanoidRootPart(model.Parent)
    end
    return nil
end

local function getDistance(position)
    local character = getCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not position then
        return math.huge
    end
    return (root.Position - position).Magnitude
end

local function roundNumber(value)
    if typeof(value) ~= "number" then
        return tostring(value)
    end
    return string.format("%.1f", value)
end

local function formatVector3(vector)
    if typeof(vector) ~= "Vector3" then
        return tostring(vector)
    end
    return string.format("%.1f, %.1f, %.1f", vector.X, vector.Y, vector.Z)
end

local function shallowCount(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count += 1
    end
    return count
end

local function formatValue(value, depth)
    depth = depth or 0
    local valueType = typeof(value)
    if value == nil then
        return "-"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        if math.abs(value) >= 1000 then
            return string.format("%.0f", value)
        end
        return roundNumber(value)
    elseif valueType == "string" then
        if #value > 64 then
            return value:sub(1, 61) .. "..."
        end
        return value
    elseif valueType == "Vector3" then
        return formatVector3(value)
    elseif valueType == "CFrame" then
        return formatVector3(value.Position)
    elseif valueType == "Instance" then
        return value.ClassName .. ":" .. value.Name
    elseif valueType == "table" then
        if depth >= 1 then
            return "table(" .. tostring(shallowCount(value)) .. ")"
        end
        local pieces = {}
        local limit = 0
        for key, item in pairs(value) do
            limit += 1
            if limit > 4 then
                table.insert(pieces, "...")
                break
            end
            table.insert(pieces, tostring(key) .. "=" .. formatValue(item, depth + 1))
        end
        return "{" .. table.concat(pieces, ", ") .. "}"
    end
    return tostring(value)
end

local function toggleText(value)
    return value and "开" or "关"
end

local function modeText(value)
    local map = {
        Unknown = "未知",
        Lobby = "大厅",
        Neutral = "中立",
        None = "无",
        Enabled = "已启用",
        Disabled = "已禁用",
        Standing = "站立",
        Crouching = "蹲伏",
        Prone = "卧倒",
        Sprinting = "冲刺",
        Walking = "行走",
        Running = "奔跑",
        Idle = "待机",
        Head = "头部",
        UpperTorso = "上半身",
        HumanoidRootPart = "身体中心",
        RemoteEvent = "远程事件",
        UnreliableRemoteEvent = "不可靠远程事件",
        RemoteFunction = "远程函数",
        AUTO = "自动",
        MANUAL = "手动"
    }
    return map[value] or tostring(value)
end

local function fieldText(value)
    local map = {
        Loaded = "已加载",
        Spawned = "已生成",
        GodMode = "无敌状态",
        Drowning = "溺水状态",
        Aiming = "瞄准中",
        Stance = "姿态",
        VendorCooldown = "商人冷却",
        Respawns = "复活次数",
        CanRevive = "可救援",
        Invisible = "隐身标记",
        BuildingDebounce = "建造冷却"
    }
    return map[value] or tostring(value)
end

local function visibleValueText(value)
    if value == nil then
        return "无"
    end
    if typeof(value) == "boolean" then
        return value and "是" or "否"
    end
    if typeof(value) == "string" then
        local plainValue = value
        if plainValue:match('^".*"$') then
            plainValue = plainValue:sub(2, -2)
        end
        local mappedModeText = modeText(plainValue)
        if mappedModeText ~= plainValue then
            return mappedModeText
        end
        local mappedFieldText = fieldText(plainValue)
        if mappedFieldText ~= plainValue then
            return mappedFieldText
        end
        return plainValue
    end
    return formatValue(value)
end

local function summarizeArgs(args)
    local packed = {}
    local count = math.min(args.n or #args, 4)
    for index = 1, count do
        packed[index] = formatValue(args[index], 1)
    end
    if (args.n or #args) > 4 then
        table.insert(packed, "...")
    end
    return table.concat(packed, " | ")
end

local function safeRequire(instance)
    local ok, result = pcall(require, instance)
    if ok then
        return result
    end
    return nil
end

local function destroyNamedArtifacts(root, targetName)
    if not root then
        return
    end

    for _, child in ipairs(root:GetChildren()) do
        if child.Name == targetName then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    local descendants = root:GetDescendants()
    for index = #descendants, 1, -1 do
        local descendant = descendants[index]
        if descendant.Name == targetName then
            pcall(function()
                descendant:Destroy()
            end)
        end
    end
end

local guiParent = pickGuiParent()
local seenRoots = {}
for _, root in ipairs({ guiParent, CoreGui, Workspace }) do
    if root and not seenRoots[root] then
        seenRoots[root] = true
        destroyNamedArtifacts(root, GUI_NAME)
        destroyNamedArtifacts(root, FOV_GUI_NAME)
        destroyNamedArtifacts(root, GUI_NAME .. "_Markers")
    end
end

local markerFolder = Workspace:FindFirstChild(GUI_NAME .. "_Markers")
markerFolder = Instance.new("Folder")
markerFolder.Name = GUI_NAME .. "_Markers"
markerFolder.Parent = Workspace

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100

local fovGui = Instance.new("ScreenGui")
fovGui.Name = FOV_GUI_NAME
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fovGui.DisplayOrder = 101

if syn and syn.protect_gui then
    pcall(syn.protect_gui, screenGui)
    pcall(syn.protect_gui, fovGui)
end

screenGui.Parent = guiParent
fovGui.Parent = guiParent

local function styleCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
end

local function styleStroke(instance, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or theme.stroke
    stroke.Thickness = thickness or 1
    stroke.Parent = instance
end

local function create(className, props)
    local instance = Instance.new(className)
    for key, value in pairs(props or {}) do
        instance[key] = value
    end
    return instance
end

local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(EXPANDED_MAIN_SIZE.X, EXPANDED_MAIN_SIZE.Y),
    BackgroundColor3 = theme.bg,
    Parent = screenGui
})
styleCorner(main, 10)
styleStroke(main, theme.stroke, 1)

local mainScale = Instance.new("UIScale")
mainScale.Scale = 1
mainScale.Parent = main

local topBar = create("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = theme.panel,
    Parent = main
})
styleCorner(topBar, 10)

local topMask = create("Frame", {
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(0, 20),
    Size = UDim2.new(1, 0, 0, 34),
    Parent = topBar
})

local title = create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 10),
    Size = UDim2.new(1, -250, 0, 18),
    Font = Enum.Font.GothamBold,
    Text = "三角洲作战控制台",
    TextColor3 = theme.text,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topBar
})

local subtitle = create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 28),
    Size = UDim2.new(1, -250, 0, 16),
    Font = Enum.Font.Gotham,
    Text = "项目三角洲本地调试台 | 任务 / 派系 / 制作 / 建造 / 网络 / 路线",
    TextColor3 = theme.subtext,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topBar
})

local closeButton = create("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(34, 28),
    BackgroundColor3 = theme.danger,
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = theme.text,
    TextSize = 14,
    Parent = topBar
})
styleCorner(closeButton, 8)

local collapseButton = create("TextButton", {
    Name = "CollapseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -56, 0.5, 0),
    Size = UDim2.fromOffset(34, 28),
    BackgroundColor3 = theme.panelAlt,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = theme.text,
    TextSize = 18,
    Parent = topBar
})
styleCorner(collapseButton, 8)
styleStroke(collapseButton)

local leftRail = create("Frame", {
    Name = "LeftRail",
    Position = UDim2.fromOffset(12, 68),
    Size = UDim2.new(0, 164, 1, -118),
    BackgroundColor3 = theme.panel,
    Parent = main
})
styleCorner(leftRail, 10)
styleStroke(leftRail)

local railLayout = Instance.new("UIListLayout")
railLayout.Padding = UDim.new(0, 8)
railLayout.Parent = leftRail

local railPadding = Instance.new("UIPadding")
railPadding.PaddingTop = UDim.new(0, 12)
railPadding.PaddingLeft = UDim.new(0, 10)
railPadding.PaddingRight = UDim.new(0, 10)
railPadding.PaddingBottom = UDim.new(0, 10)
railPadding.Parent = leftRail

local contentHolder = create("Frame", {
    Name = "ContentHolder",
    Position = UDim2.fromOffset(188, 68),
    Size = UDim2.new(1, -200, 1, -118),
    BackgroundColor3 = theme.panel,
    Parent = main
})
styleCorner(contentHolder, 10)
styleStroke(contentHolder)

local footer = create("Frame", {
    Name = "Footer",
    Position = UDim2.new(0, 12, 1, -44),
    Size = UDim2.new(1, -24, 0, 32),
    BackgroundColor3 = theme.panel,
    Parent = main
})
styleCorner(footer, 8)
styleStroke(footer)

local footerLeft = create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(0.68, 0, 1, 0),
    Font = Enum.Font.Gotham,
    Text = "准备中",
    TextColor3 = theme.subtext,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = footer
})

local footerRight = create("TextLabel", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 0),
    Size = UDim2.new(0.3, 0, 1, 0),
    Font = Enum.Font.Gotham,
    Text = "热键：左Alt隐藏，结束键销毁",
    TextColor3 = theme.subtext,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = footer
})

local fovCircle = create("Frame", {
    Name = "锁定圈",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(380, 380),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
    Parent = fovGui
})
styleCorner(fovCircle, 999)

local fovCircleFill = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -8, 1, -8),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.95,
    BorderSizePixel = 0,
    ZIndex = 20,
    Parent = fovCircle
})
styleCorner(fovCircleFill, 999)

local fovCircleStroke = Instance.new("UIStroke")
fovCircleStroke.Color = theme.accent
fovCircleStroke.Thickness = 2
fovCircleStroke.Transparency = 0.12
fovCircleStroke.Parent = fovCircle

local fovCircleLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 0, -8),
    Size = UDim2.fromOffset(220, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    Text = "锁定圈",
    TextColor3 = theme.accent,
    TextSize = 12,
    ZIndex = 21,
    Parent = fovCircle
})

local tabButtons = {}
local pages = {}
local pageBodies = {}
local connections = {}
local pageOrder = { "概览", "场景", "玩家", "网络", "战斗", "动作" }
local targetPriorityModes = { "准星优先", "距离优先", "优先玩家", "优先NPC" }

local state = {
    alive = true,
    collapsed = false,
    hidden = false,
    currentPage = "概览",
    lastAction = "已启动",
    remoteLogs = {},
    hookInstalled = false,
    hookStatus = "未安装",
    remoteHookEnabled = false,
    npcEsp = true,
    containerEsp = true,
    promptEsp = false,
    playerEsp = false,
    combatEnabled = false,
    npcLockEnabled = false,
    showFovCircle = true,
    lockCamera = true,
    autoTrack = false,
    triggerBot = false,
    recoilPatch = false,
    autoSelectClosest = true,
    respectFov = true,
    requireVisible = true,
    targetPriorityMode = "准星优先",
    targetPart = "Head",
    combatFov = 190,
    combatMaxDistance = 420,
    aimSmoothness = 0.16,
    combatStatus = "待机",
    targetName = nil,
    selectedTarget = nil,
    selectedNpcName = nil,
    lastTriggerShot = 0,
    currentWeapon = nil,
    currentWeaponStats = nil,
    currentAmmoStats = nil,
    currentEquippedToolName = nil,
    originalWeaponSettings = {},
    scans = {
        npcs = {},
        containers = {},
        prompts = {},
        players = {},
        remotes = { events = {}, functions = {} },
        anchors = {},
        weapons = {}
    },
    markers = {}
}

local cachedModules = {
    Quests = safeRequire(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Quests")),
    FactionRelations = safeRequire(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("FactionRelations")),
    AimAssist = safeRequire(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("AimAssist"))
}

local function getViewportSize()
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

local function isPhoneTouchViewport(viewport)
    return UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) <= 1400
end

local function getCurrentMainSize(viewport)
    viewport = viewport or getViewportSize()
    if isPhoneTouchViewport(viewport) then
        return state.collapsed and PHONE_COLLAPSED_MAIN_SIZE or PHONE_EXPANDED_MAIN_SIZE
    end
    if UserInputService.TouchEnabled then
        return state.collapsed and TOUCH_COLLAPSED_MAIN_SIZE or TOUCH_EXPANDED_MAIN_SIZE
    end
    return state.collapsed and COLLAPSED_MAIN_SIZE or EXPANDED_MAIN_SIZE
end

local function applyResponsiveLayout()
    local viewport = getViewportSize()
    local baseSize = getCurrentMainSize(viewport)
    local touchLayout = UserInputService.TouchEnabled
    local phoneTouch = isPhoneTouchViewport(viewport)
    local compactLayout = touchLayout or viewport.X < 1180 or viewport.Y < 760
    local horizontalPadding = phoneTouch and 40 or (compactLayout and 24 or 48)
    local verticalPadding = phoneTouch and 30 or (compactLayout and 24 or 48)
    local widthScale = math.max((viewport.X - horizontalPadding) / baseSize.X, 0.2)
    local heightScale = math.max((viewport.Y - verticalPadding) / baseSize.Y, 0.2)
    local scale = math.min(widthScale, heightScale, 1)

    if touchLayout then
        local touchScaleCap
        if phoneTouch then
            touchScaleCap = state.collapsed and 0.62 or 0.78
        else
            touchScaleCap = state.collapsed and 0.74 or 0.9
        end
        scale = math.min(scale, touchScaleCap)
    end

    mainScale.Scale = math.clamp(scale, 0.28, 1)
    local topBarHeight = phoneTouch and 46 or (touchLayout and 50 or 54)
    local topMaskOffset = math.max(topBarHeight - 34, 12)
    local outerMargin = phoneTouch and 10 or 12
    local footerHeight = phoneTouch and 28 or 32
    local footerMargin = phoneTouch and 8 or 12
    local bottomGap = 6
    local railWidth = phoneTouch and 150 or 164
    local railGap = 12
    local railTop = topBarHeight + 14
    local buttonSize = phoneTouch and Vector2.new(32, 28) or (compactLayout and Vector2.new(38, 30) or Vector2.new(34, 28))
    local buttonRightInset = phoneTouch and 10 or 14
    local buttonGap = phoneTouch and 8 or 10

    topBar.Size = UDim2.new(1, 0, 0, topBarHeight)
    topMask.Position = UDim2.fromOffset(0, topMaskOffset)
    topMask.Size = UDim2.new(1, 0, 0, topBarHeight - topMaskOffset)
    leftRail.Position = UDim2.fromOffset(outerMargin, railTop)
    leftRail.Size = UDim2.new(0, railWidth, 1, -(railTop + footerHeight + footerMargin + bottomGap))
    contentHolder.Position = UDim2.fromOffset(outerMargin + railWidth + railGap, railTop)
    contentHolder.Size = UDim2.new(1, -((outerMargin * 2) + railWidth + railGap), 1, -(railTop + footerHeight + footerMargin + bottomGap))
    footer.Position = UDim2.new(0, outerMargin, 1, -(footerHeight + footerMargin))
    footer.Size = UDim2.new(1, -(outerMargin * 2), 0, footerHeight)

    subtitle.Visible = not compactLayout and not state.collapsed
    footerRight.Visible = not compactLayout and not state.collapsed
    footerLeft.Position = UDim2.fromOffset(phoneTouch and 10 or 12, 0)
    footerLeft.Size = phoneTouch and UDim2.new(1, -20, 1, 0) or (compactLayout and UDim2.new(1, -24, 1, 0) or UDim2.new(0.68, 0, 1, 0))
    footerLeft.TextSize = phoneTouch and 11 or 12
    title.Size = phoneTouch and UDim2.new(1, -88, 0, 20) or (compactLayout and UDim2.new(1, -108, 0, 24) or UDim2.new(1, -250, 0, 18))
    title.Position = phoneTouch and UDim2.fromOffset(14, state.collapsed and 12 or 11) or (compactLayout and UDim2.fromOffset(16, 15) or UDim2.fromOffset(18, 10))
    title.TextSize = phoneTouch and (state.collapsed and 16 or 18) or (compactLayout and 19 or 20)
    subtitle.Position = phoneTouch and UDim2.fromOffset(14, 26) or UDim2.fromOffset(18, 28)
    subtitle.Size = phoneTouch and UDim2.new(1, -88, 0, 14) or UDim2.new(1, -250, 0, 16)
    closeButton.Size = UDim2.fromOffset(buttonSize.X, buttonSize.Y)
    collapseButton.Size = UDim2.fromOffset(buttonSize.X, buttonSize.Y)
    closeButton.Position = UDim2.new(1, -buttonRightInset, 0.5, 0)
    collapseButton.Position = UDim2.new(1, -(buttonRightInset + buttonSize.X + buttonGap), 0.5, 0)
    closeButton.TextSize = phoneTouch and 13 or 14
    collapseButton.TextSize = phoneTouch and 16 or 18
end

local function syncMainSize()
    local size = getCurrentMainSize(getViewportSize())
    main.Size = UDim2.fromOffset(size.X, size.Y)
    applyResponsiveLayout()
end

local function pushConnection(connection)
    table.insert(connections, connection)
    return connection
end

local function makePage(name)
    local scrolling = create("ScrollingFrame", {
        Name = name,
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = theme.stroke,
        Visible = false,
        Parent = contentHolder
    })

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 14)
    padding.PaddingLeft = UDim.new(0, 14)
    padding.PaddingRight = UDim.new(0, 14)
    padding.PaddingBottom = UDim.new(0, 14)
    padding.Parent = scrolling

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.Parent = scrolling

    pages[name] = scrolling
    pageBodies[name] = scrolling
    return scrolling
end

local function makeSection(page, titleText)
    local section = create("Frame", {
        BackgroundColor3 = theme.panelAlt,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = page
    })
    styleCorner(section, 8)
    styleStroke(section)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = section

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = section

    local header = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.GothamBold,
        Text = titleText,
        TextColor3 = theme.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = section
    })

    local body = create("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = section
    })

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 8)
    bodyLayout.Parent = body

    return section, body
end

local function clearBody(body)
    for _, child in ipairs(body:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local function makeButton(parent, text, callback, accentColor, width)
    local button = create("TextButton", {
        BackgroundColor3 = accentColor or theme.panel,
        Size = UDim2.fromOffset(width or 68, 28),
        AutoButtonColor = true,
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextColor3 = theme.text,
        TextSize = 12,
        Parent = parent
    })
    styleCorner(button, 7)
    if accentColor == nil then
        styleStroke(button)
    end
    pushConnection(button.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end))
    return button
end

local function makeRow(parent, titleText, detailText, actions)
    local row = create("Frame", {
        BackgroundColor3 = theme.row,
        Size = UDim2.new(1, 0, 0, 34),
        Parent = parent
    })
    styleCorner(row, 7)

    local left = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(0.34, 0, 1, 0),
        Font = Enum.Font.GothamSemibold,
        Text = titleText,
        TextColor3 = theme.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    local detail = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.34, 6, 0, 0),
        Size = UDim2.new(0.34, -12, 1, 0),
        Font = Enum.Font.Gotham,
        Text = detailText,
        TextColor3 = theme.subtext,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })

    local actionFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0.3, 0, 0, 28),
        BackgroundTransparency = 1,
        Parent = row
    })

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 6)
    layout.Parent = actionFrame

    for _, action in ipairs(actions or {}) do
        makeButton(actionFrame, action.text, action.callback, action.color, action.width)
    end

    return row
end

local function makeParagraph(parent, text, color)
    local label = create("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        Font = Enum.Font.Gotham,
        RichText = true,
        Text = text,
        TextColor3 = color or theme.subtext,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = parent
    })
    return label
end

for _, pageName in ipairs(pageOrder) do
    makePage(pageName)
end

local navHint = create("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 16),
    Font = Enum.Font.Gotham,
    Text = "本地测试 / 信息勘察 / 调试动作",
    TextColor3 = theme.subtext,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = leftRail
})

local updateLockCircle

local function switchPage(pageName)
    state.currentPage = pageName
    for name, page in pairs(pages) do
        page.Visible = (name == pageName)
    end
    for name, button in pairs(tabButtons) do
        local selected = name == pageName
        button.BackgroundColor3 = selected and theme.accent or theme.panelAlt
        button.TextColor3 = selected and theme.bg or theme.text
    end
    if updateLockCircle then
        updateLockCircle()
    end
end

for _, pageName in ipairs(pageOrder) do
    local button = create("TextButton", {
        BackgroundColor3 = theme.panelAlt,
        Size = UDim2.new(1, 0, 0, 36),
        Font = Enum.Font.GothamSemibold,
        Text = pageName,
        TextColor3 = theme.text,
        TextSize = 14,
        Parent = leftRail
    })
    styleCorner(button, 8)
    styleStroke(button)
    tabButtons[pageName] = button
    pushConnection(button.MouseButton1Click:Connect(function()
        switchPage(pageName)
    end))
end

switchPage("概览")

local refs = {
    overview = {},
    world = {},
    players = {},
    network = {},
    actions = {}
}

local _, overviewSummaryBody = makeSection(pages["概览"], "地图主循环概览")
local _, overviewStatusBody = makeSection(pages["概览"], "玩家状态变量")
local _, overviewQuestBody = makeSection(pages["概览"], "任务与角色入口")
refs.overview.summary = overviewSummaryBody
refs.overview.status = overviewStatusBody
refs.overview.quest = overviewQuestBody

local _, worldNpcBody = makeSection(pages["场景"], "任务角色列表")
local _, worldContainerBody = makeSection(pages["场景"], "容器与搜刮路径")
local _, worldPromptBody = makeSection(pages["场景"], "交互点列表")
refs.world.npcs = worldNpcBody
refs.world.containers = worldContainerBody
refs.world.prompts = worldPromptBody

local _, playersBody = makeSection(pages["玩家"], "在线玩家")
local _, cameraBody = makeSection(pages["玩家"], "视角与位移")
refs.players.list = playersBody
refs.players.camera = cameraBody

local _, networkSummaryBody = makeSection(pages["网络"], "网络层总览")
local _, networkEventsBody = makeSection(pages["网络"], "远程事件")
local _, networkFunctionsBody = makeSection(pages["网络"], "远程函数")
local _, networkLogsBody = makeSection(pages["网络"], "本地远程调用日志")
refs.network.summary = networkSummaryBody
refs.network.events = networkEventsBody
refs.network.functions = networkFunctionsBody
refs.network.logs = networkLogsBody

local _, combatTargetBody = makeSection(pages["战斗"], "目标锁定与辅助")
local _, combatWeaponBody = makeSection(pages["战斗"], "当前武器与弹药")
local _, combatToolsBody = makeSection(pages["战斗"], "战斗控制")
refs.combat = {}
refs.combat.target = combatTargetBody
refs.combat.weapon = combatWeaponBody
refs.combat.tools = combatToolsBody

local _, actionsTogglesBody = makeSection(pages["动作"], "调试开关")
local _, actionsTravelBody = makeSection(pages["动作"], "快速跳转")
local _, actionsUtilityBody = makeSection(pages["动作"], "工具动作")
refs.actions.toggles = actionsTogglesBody
refs.actions.travel = actionsTravelBody
refs.actions.utility = actionsUtilityBody

local function setLastAction(text)
    state.lastAction = text
end

updateLockCircle = function()
    local diameter = math.max(120, math.floor(state.combatFov * 2))
    local circleVisible = state.alive and state.showFovCircle
    local labelVisible = circleVisible and not state.hidden and not state.collapsed and state.currentPage == "战斗"

    fovGui.Enabled = circleVisible
    fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    fovCircle.Visible = circleVisible
    fovCircleFill.Visible = circleVisible
    fovCircleStroke.Enabled = circleVisible
    fovCircleStroke.Color = (state.combatEnabled or state.npcLockEnabled) and theme.success or theme.accent
    fovCircleLabel.Text = string.format("锁定圈半径 %.0f", state.combatFov)
    fovCircleLabel.Visible = labelVisible
    fovCircleLabel.TextColor3 = fovCircleStroke.Color
end

local function getRsPlayer()
    local playersFolder = ReplicatedStorage:FindFirstChild("Players")
    return playersFolder and playersFolder:FindFirstChild(LocalPlayer.Name) or nil
end

local function getGameMode()
    local serverInfo = ReplicatedFirst:FindFirstChild("ServerInfo")
    if not serverInfo then
        return "未知"
    end
    return modeText(serverInfo:GetAttribute("GameMode") or "Unknown")
end

local function getQuestAvailability(npcName)
    local questModule = cachedModules.Quests
    if not questModule or type(questModule.GetAvailableQuest) ~= "function" then
        return false
    end
    local ok, available = pcall(function()
        return questModule:GetAvailableQuest(LocalPlayer, npcName)
    end)
    return ok and available and true or false
end

local function teleportToPosition(position)
    local character = getCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
end

local function focusCharacter(player)
    local targetCharacter = player and player.Character
    local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if humanoid and Workspace.CurrentCamera then
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = humanoid
        setLastAction("视角锁定: " .. player.Name)
    end
end

local function restoreCamera()
    local character = getCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and Workspace.CurrentCamera then
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = humanoid
        setLastAction("视角恢复本体")
    end
end

local function getCurrentEquippedObject()
    local rsPlayer = getRsPlayer()
    local gameplay = rsPlayer and rsPlayer:FindFirstChild("Status")
        and rsPlayer.Status:FindFirstChild("GameplayVariables")
    local equipped = gameplay and gameplay:FindFirstChild("EquippedTool")
    return equipped and equipped.Value or nil
end

local function getItemSettings(itemName)
    if not itemName then
        return nil
    end
    local itemsList = ReplicatedStorage:FindFirstChild("ItemsList")
    local itemFolder = itemsList and itemsList:FindFirstChild(itemName)
    local settingsModule = itemFolder and itemFolder:FindFirstChild("SettingsModule")
    if settingsModule then
        return safeRequire(settingsModule)
    end
    return nil
end

local function getCurrentWeaponContext()
    local equipped = getCurrentEquippedObject()
    local weaponName = equipped and equipped.Name or nil
    local weaponFolder = weaponName and ReplicatedStorage:FindFirstChild("RangedWeapons")
        and ReplicatedStorage.RangedWeapons:FindFirstChild(weaponName) or nil
    local weaponAttrs = weaponFolder and weaponFolder:GetAttributes() or nil
    local itemSettings = getItemSettings(weaponName)

    local ammoName
    if weaponFolder then
        ammoName = weaponFolder:GetAttribute("DefaultAmmo")
    end

    local ammoFolder = ammoName and ReplicatedStorage:FindFirstChild("AmmoTypes")
        and ReplicatedStorage.AmmoTypes:FindFirstChild(ammoName) or nil
    local ammoAttrs = ammoFolder and ammoFolder:GetAttributes() or nil

    return {
        object = equipped,
        name = weaponName,
        weaponFolder = weaponFolder,
        weaponAttrs = weaponAttrs,
        itemSettings = itemSettings,
        ammoName = ammoName,
        ammoAttrs = ammoAttrs
    }
end

local function readWeaponValue(ctx, key, fallback)
    if ctx and ctx.itemSettings and ctx.itemSettings[key] ~= nil then
        return ctx.itemSettings[key]
    end
    if ctx and ctx.weaponAttrs and ctx.weaponAttrs[key] ~= nil then
        return ctx.weaponAttrs[key]
    end
    return fallback
end

local function readAmmoValue(ctx, key, fallback)
    if ctx and ctx.ammoAttrs and ctx.ammoAttrs[key] ~= nil then
        return ctx.ammoAttrs[key]
    end
    return fallback
end

local function getTargetPart(character)
    if not character then
        return nil
    end
    return character:FindFirstChild(state.targetPart)
        or character:FindFirstChild("FaceHitBox")
        or character:FindFirstChild("Head")
        or character:FindFirstChild("HumanoidRootPart")
end

local function getScreenDistance(worldPosition)
    local camera = Workspace.CurrentCamera
    if not camera then
        return math.huge, false, nil
    end
    local viewport = camera.ViewportSize / 2
    local projected, visible = camera:WorldToViewportPoint(worldPosition)
    local distance = (Vector2.new(projected.X, projected.Y) - viewport).Magnitude
    return distance, visible, projected
end

local function clearSelectedTarget()
    state.selectedTarget = nil
    state.targetName = nil
end

local function selectTarget(targetInfo)
    state.selectedTarget = targetInfo
    state.targetName = targetInfo and targetInfo.name or nil
end

local function scanAnchors()
    local anchors = {}
    local spawn = Workspace:FindFirstChild("SpawnLocation")
    if spawn and spawn:IsA("BasePart") then
        anchors["主出生点"] = spawn.Position
    end
    local modStation = Workspace:FindFirstChild("ModificationStation", true)
    local modRoot = modStation and getHumanoidRootPart(modStation)
    if modRoot then
        anchors["改装台"] = modRoot.Position
    end
    local total = Vector3.zero
    local count = 0
    for _, npc in ipairs(state.scans.npcs) do
        total += npc.position
        count += 1
    end
    if count > 0 then
        anchors["角色大厅"] = total / count
    end
    state.scans.anchors = anchors
end

local function getWorkspaceRootModel(instance)
    local current = instance
    local candidate = nil
    while current and current ~= Workspace do
        if current:IsA("Model") then
            candidate = current
        end
        local parent = current.Parent
        if parent == Workspace then
            return current:IsA("Model") and current or candidate
        end
        current = parent
    end
    return candidate
end

local function isPlayerOwnedModel(model)
    if not model then
        return false
    end
    if Players:GetPlayerFromCharacter(model) then
        return true
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and model:IsDescendantOf(player.Character) then
            return true
        end
    end
    return false
end

local function shouldIgnoreNpcModel(model)
    if not model then
        return true
    end
    if model:IsDescendantOf(Workspace.Camera) then
        return true
    end
    if model == markerFolder or model:IsDescendantOf(markerFolder) then
        return true
    end
    if LocalPlayer.Character and model:IsDescendantOf(LocalPlayer.Character) then
        return true
    end
    if isPlayerOwnedModel(model) then
        return true
    end
    local parent = model.Parent
    if parent and (parent.Name == "Containers" or parent.Name == "DroppedItems") then
        return true
    end
    return false
end

local function scanNpcs()
    local npcs = {}
    local seen = {}
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") then
            local rootModel = getWorkspaceRootModel(descendant)
            if rootModel and not seen[rootModel] and not shouldIgnoreNpcModel(rootModel) then
                local hint = rootModel:FindFirstChild("Hint", true)
                local humanoid = rootModel:FindFirstChildOfClass("Humanoid")
                if hint or humanoid then
                    seen[rootModel] = true
                    local root = getHumanoidRootPart(rootModel)
                    if root then
                        table.insert(npcs, {
                            name = rootModel.Name,
                            model = rootModel,
                            position = root.Position,
                            distance = getDistance(root.Position),
                            velocity = root.AssemblyLinearVelocity,
                            health = humanoid and humanoid.Health or 0,
                            maxHealth = humanoid and humanoid.MaxHealth or 0,
                            hasQuest = hint ~= nil and getQuestAvailability(rootModel.Name) or false,
                            hasHint = hint ~= nil
                        })
                    end
                end
            end
        end
    end
    table.sort(npcs, function(a, b)
        return a.distance < b.distance
    end)
    state.scans.npcs = npcs
end

local function scanContainers()
    local containers = {}
    local folder = Workspace:FindFirstChild("Containers")
    if not folder then
        state.scans.containers = containers
        return
    end
    for index, child in ipairs(folder:GetChildren()) do
        local root = getHumanoidRootPart(child)
        if root then
            table.insert(containers, {
                id = child.Name .. "#" .. tostring(index),
                name = child.Name,
                object = child,
                position = root.Position,
                distance = getDistance(root.Position)
            })
        end
    end
    table.sort(containers, function(a, b)
        return a.distance < b.distance
    end)
    state.scans.containers = containers
end

local function scanPrompts()
    local prompts = {}
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            local root = getHumanoidRootPart(descendant)
            if root then
                table.insert(prompts, {
                    id = descendant:GetFullName(),
                    prompt = descendant,
                    objectText = descendant.ObjectText,
                    actionText = descendant.ActionText,
                    position = root.Position,
                    distance = getDistance(root.Position),
                    enabled = descendant.Enabled
                })
            end
        end
    end
    table.sort(prompts, function(a, b)
        return a.distance < b.distance
    end)
    state.scans.prompts = prompts
end

local function scanPlayers()
    local scan = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if root and humanoid then
                local playerInfo = {}
                playerInfo.name = player.Name
                playerInfo.player = player
                playerInfo.character = player.Character
                playerInfo.position = root.Position
                playerInfo.velocity = root.AssemblyLinearVelocity
                playerInfo.distance = getDistance(root.Position)
                playerInfo.health = humanoid.Health
                playerInfo.maxHealth = humanoid.MaxHealth
                playerInfo.team = modeText(player.Team and player.Team.Name or (player.Neutral and "Neutral" or "None"))
                scan[#scan + 1] = playerInfo
            end
        end
    end
    table.sort(scan, function(a, b)
        return a.distance < b.distance
    end)
    state.scans.players = scan
end

local function scanRemotes()
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
    local events = {}
    local functionsList = {}
    if remoteFolder then
        for _, child in ipairs(remoteFolder:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("UnreliableRemoteEvent") then
                table.insert(events, child)
            elseif child:IsA("RemoteFunction") then
                table.insert(functionsList, child)
            end
        end
    end
    table.sort(events, function(a, b)
        return a.Name < b.Name
    end)
    table.sort(functionsList, function(a, b)
        return a.Name < b.Name
    end)
    state.scans.remotes.events = events
    state.scans.remotes.functions = functionsList
end

local function scanWeapons()
    local ctx = getCurrentWeaponContext()
    state.currentWeapon = ctx.object
    state.currentEquippedToolName = ctx.name
    state.currentWeaponStats = ctx.itemSettings
    state.currentAmmoStats = ctx.ammoAttrs
    state.scans.weapons = ctx
end

local function removeMarker(key)
    local marker = state.markers[key]
    if marker then
        marker:Destroy()
        state.markers[key] = nil
    end
end

local function ensureHighlight(key, adornee, color)
    if not adornee then
        removeMarker(key)
        return
    end
    local highlight = state.markers[key]
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = key
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.82
        highlight.OutlineTransparency = 0.05
        highlight.Parent = markerFolder
        state.markers[key] = highlight
    end
    highlight.Adornee = adornee
    highlight.FillColor = color
    highlight.OutlineColor = color
end

local function refreshMarkers()
    local active = {}

    if state.npcEsp then
        for _, npc in ipairs(state.scans.npcs) do
            local key = "NPC_" .. npc.name
            active[key] = true
            ensureHighlight(key, npc.model, theme.npc)
        end
    end

    if state.containerEsp then
        for _, container in ipairs(state.scans.containers) do
            local key = "CON_" .. container.id
            active[key] = true
            ensureHighlight(key, container.object, theme.container)
        end
    end

    if state.promptEsp then
        for _, promptInfo in ipairs(state.scans.prompts) do
            local key = "PROMPT_" .. promptInfo.id
            active[key] = true
            ensureHighlight(key, promptInfo.prompt.Parent, theme.prompt)
        end
    end

    if state.playerEsp then
        for _, playerInfo in ipairs(state.scans.players) do
            local key = "PLY_" .. playerInfo.name
            active[key] = true
            ensureHighlight(key, playerInfo.character, theme.player)
        end
    end

    for key in pairs(state.markers) do
        if not active[key] then
            removeMarker(key)
        end
    end
end

local function pushRemoteLog(method, remoteInstance, args, fromExecutor)
    local entry = {
        t = os.clock(),
        method = method,
        name = remoteInstance.Name,
        path = remoteInstance:GetFullName(),
        args = summarizeArgs(args),
        source = fromExecutor and "执行器" or "客户端"
    }
    table.insert(state.remoteLogs, 1, entry)
    while #state.remoteLogs > REMOTE_LOG_LIMIT do
        table.remove(state.remoteLogs)
    end
end

local function installRemoteHook()
    if state.hookInstalled then
        state.hookStatus = "已就绪"
        return true
    end

    if not (hookmetamethod and getnamecallmethod and newcclosure) then
        state.hookStatus = "当前执行器不支持本地远程调用钩子"
        return false
    end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if state.remoteHookEnabled and typeof(self) == "Instance" then
            if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent") then
                local fromExecutor = checkcaller and checkcaller() or false
                local packed = table.pack(...)
                pushRemoteLog(method, self, packed, fromExecutor)
            end
        end
        return oldNamecall(self, ...)
    end))

    state.hookInstalled = true
    state.hookStatus = "已安装"
    return true
end

local function firePrompt(prompt)
    if not prompt then
        return
    end
    if fireproximityprompt then
        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)
        if ok then
            setLastAction("触发提示: " .. prompt.Name)
        end
    else
        setLastAction("当前执行器不支持提示触发")
    end
end

local function refreshScans()
    scanNpcs()
    scanContainers()
    scanPrompts()
    scanPlayers()
    scanRemotes()
    scanWeapons()
    scanAnchors()
    refreshMarkers()
end

local function isTargetVisible(targetCharacter, targetPart)
    local camera = Workspace.CurrentCamera
    local localCharacter = getCharacter()
    if not camera or not localCharacter or not targetCharacter or not targetPart then
        return false
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude <= 0.01 then
        return true
    end

    local exclusions = { localCharacter, camera, markerFolder }
    for _ = 1, 6 do
        params.FilterDescendantsInstances = exclusions
        local result = Workspace:Raycast(origin, direction, params)
        if not result then
            return true
        end

        local hit = result.Instance
        if hit and hit:IsDescendantOf(targetCharacter) then
            return true
        end

        if hit and hit:IsA("BasePart") and (hit.Transparency >= 0.95 or not hit.CanCollide) then
            table.insert(exclusions, hit)
            origin = result.Position + direction.Unit * 0.05
            direction = targetPart.Position - origin
            if direction.Magnitude <= 0.01 then
                return true
            end
        else
            return false
        end
    end

    return false
end

local function buildCombatInfo(playerInfo)
    if not playerInfo or playerInfo.health <= 0 then
        return nil
    end

    local targetPart = getTargetPart(playerInfo.character)
    if not targetPart then
        return nil
    end

    local screenDistance, onScreen = getScreenDistance(targetPart.Position)
    local visible = isTargetVisible(playerInfo.character, targetPart)
    local score = screenDistance + playerInfo.distance * 0.08 + (visible and 0 or 80)

    return {
        name = playerInfo.name,
        player = playerInfo.player,
        isNpc = false,
        character = playerInfo.character,
        aimPart = targetPart,
        position = targetPart.Position,
        velocity = playerInfo.velocity or Vector3.zero,
        distance = playerInfo.distance,
        health = playerInfo.health,
        maxHealth = playerInfo.maxHealth,
        team = playerInfo.team,
        screenDistance = screenDistance,
        onScreen = onScreen,
        visible = visible,
        score = score
    }
end

local function buildNpcCombatInfo(npcInfo)
    if not npcInfo or (npcInfo.maxHealth or 0) > 0 and (npcInfo.health or 0) <= 0 then
        return nil
    end

    local targetPart = getTargetPart(npcInfo.model)
    if not targetPart then
        return nil
    end

    local screenDistance, onScreen = getScreenDistance(targetPart.Position)
    local visible = isTargetVisible(npcInfo.model, targetPart)
    local score = screenDistance + npcInfo.distance * 0.05 + (visible and 0 or 80)

    return {
        name = npcInfo.name,
        isNpc = true,
        character = npcInfo.model,
        aimPart = targetPart,
        position = targetPart.Position,
        velocity = npcInfo.velocity or Vector3.zero,
        distance = npcInfo.distance,
        health = npcInfo.health or 0,
        maxHealth = npcInfo.maxHealth or 0,
        team = npcInfo.hasQuest and "任务角色" or "场景角色",
        screenDistance = screenDistance,
        onScreen = onScreen,
        visible = visible,
        score = score
    }
end

local function getNamedTarget()
    if not state.targetName then
        return nil
    end
    for _, playerInfo in ipairs(state.scans.players) do
        if playerInfo.name == state.targetName then
            return buildCombatInfo(playerInfo)
        end
    end
    return nil
end

local function getNamedNpcTarget()
    if not state.selectedNpcName then
        return nil
    end
    for _, npcInfo in ipairs(state.scans.npcs) do
        if npcInfo.name == state.selectedNpcName then
            return buildNpcCombatInfo(npcInfo)
        end
    end
    return nil
end

local function canUseCombatTarget(targetInfo, options)
    options = options or {}
    if not targetInfo then
        return false
    end
    if targetInfo.distance > state.combatMaxDistance then
        return false
    end
    local requireOnScreen = options.requireOnScreen
    if requireOnScreen == nil then
        requireOnScreen = true
    end
    if requireOnScreen and not targetInfo.onScreen then
        return false
    end
    local requireFov = options.requireFov
    if requireFov == nil then
        requireFov = state.respectFov
    end
    if requireFov and targetInfo.screenDistance > state.combatFov then
        return false
    end
    local requireVisible = options.requireVisible
    if requireVisible == nil then
        requireVisible = state.requireVisible
    end
    if requireVisible and not targetInfo.visible then
        return false
    end
    return true
end

local function chooseBetterCombatTarget(left, right)
    if not left then
        return right
    end
    if not right then
        return left
    end

    local mode = state.targetPriorityMode
    if mode == "优先玩家" then
        if left.isNpc ~= right.isNpc then
            return left.isNpc and right or left
        end
    elseif mode == "优先NPC" then
        if left.isNpc ~= right.isNpc then
            return left.isNpc and left or right
        end
    elseif mode == "距离优先" then
        if math.abs(left.distance - right.distance) > 0.01 then
            return left.distance < right.distance and left or right
        end
        if math.abs(left.screenDistance - right.screenDistance) > 0.01 then
            return left.screenDistance < right.screenDistance and left or right
        end
        return left.score <= right.score and left or right
    end

    if math.abs(left.screenDistance - right.screenDistance) > 0.01 then
        return left.screenDistance < right.screenDistance and left or right
    end
    if math.abs(left.distance - right.distance) > 0.01 then
        return left.distance < right.distance and left or right
    end
    return left.score <= right.score and left or right
end

local function getNextTargetPriorityMode()
    for index, mode in ipairs(targetPriorityModes) do
        if mode == state.targetPriorityMode then
            return targetPriorityModes[index % #targetPriorityModes + 1]
        end
    end
    return targetPriorityModes[1]
end

local function chooseCombatTarget()
    local namedTarget = getNamedTarget()
    if namedTarget then
        if canUseCombatTarget(namedTarget, {
            requireOnScreen = false,
            requireFov = false
        }) then
            return namedTarget
        end
    elseif state.targetName then
        clearSelectedTarget()
    end

    if not state.autoSelectClosest then
        return nil
    end

    local best
    for _, playerInfo in ipairs(state.scans.players) do
        local candidate = buildCombatInfo(playerInfo)
        if canUseCombatTarget(candidate) then
            best = chooseBetterCombatTarget(best, candidate)
        end
    end
    return best
end

local function clearSelectedNpcTarget()
    state.selectedNpcName = nil
end

local function selectNpcTarget(npcInfo)
    state.selectedNpcName = npcInfo and npcInfo.name or nil
end

local function chooseNpcCombatTarget()
    if not state.npcLockEnabled then
        return nil, "NPC锁定未开启"
    end

    local npcTarget = getNamedNpcTarget()
    if npcTarget and canUseCombatTarget(npcTarget, {
        requireOnScreen = false,
        requireFov = false
    }) then
        return npcTarget
    end

    local best
    for _, npcInfo in ipairs(state.scans.npcs) do
        local candidate = buildNpcCombatInfo(npcInfo)
        if canUseCombatTarget(candidate) then
            best = chooseBetterCombatTarget(best, candidate)
        end
    end

    if best then
        return best
    end

    if npcTarget then
        if npcTarget.distance > state.combatMaxDistance then
            return nil, "NPC超出最远距离"
        end
        if state.requireVisible and not npcTarget.visible then
            return nil, "NPC被墙体遮挡"
        end
        return nil, "已选NPC当前不可锁定"
    end

    return nil, "未找到可锁定NPC"
end

local function chooseMergedCombatTarget()
    local playerTarget = chooseCombatTarget()
    local npcTarget, npcReason

    if state.npcLockEnabled then
        npcTarget, npcReason = chooseNpcCombatTarget()
    end

    if playerTarget and npcTarget then
        local playerIsManual = state.targetName and playerTarget.name == state.targetName
        local npcIsManual = state.selectedNpcName and npcTarget.name == state.selectedNpcName

        if playerIsManual ~= npcIsManual then
            return playerIsManual and playerTarget or npcTarget
        end

        return chooseBetterCombatTarget(playerTarget, npcTarget)
    end

    if playerTarget then
        return playerTarget
    end

    if npcTarget then
        return npcTarget
    end

    return nil, npcReason or "未找到有效目标"
end

local function applyRecoilPatch(enabled)
    local rangedWeapons = ReplicatedStorage:FindFirstChild("RangedWeapons")
    if not rangedWeapons then
        return
    end

    for _, weaponFolder in ipairs(rangedWeapons:GetChildren()) do
        local settings = getItemSettings(weaponFolder.Name)
        if type(settings) == "table" and settings.FireRate then
            if enabled then
                if not state.originalWeaponSettings[weaponFolder.Name] then
                    state.originalWeaponSettings[weaponFolder.Name] = {
                        MaxRecoil = settings.MaxRecoil,
                        RecoilReductionMax = settings.RecoilReductionMax,
                        RecoilTValueMax = settings.RecoilTValueMax,
                        IdleSwayModifier = settings.IdleSwayModifier,
                        WalkSwayModifer = settings.WalkSwayModifer,
                        SprintSwayModifer = settings.SprintSwayModifer,
                        swayMult = settings.swayMult,
                        MaximumKickBack = settings.MaximumKickBack
                    }
                end
                settings.MaxRecoil = 0
                settings.RecoilReductionMax = 0
                settings.RecoilTValueMax = 0
                settings.IdleSwayModifier = 0.05
                settings.WalkSwayModifer = 0.05
                settings.SprintSwayModifer = 0.05
                settings.swayMult = 0.05
                settings.MaximumKickBack = 0
            else
                local original = state.originalWeaponSettings[weaponFolder.Name]
                if original then
                    for key, value in pairs(original) do
                        settings[key] = value
                    end
                end
            end
        end
    end
end

local function attemptTriggerShot(targetInfo)
    if not state.triggerBot or not targetInfo or not targetInfo.visible then
        return
    end
    if targetInfo.screenDistance > math.min(state.combatFov * 0.32, 42) then
        return
    end

    local weaponCtx = state.scans.weapons
    local fireRate = readWeaponValue(weaponCtx, "FireRate", nil)
    if not fireRate then
        return
    end

    local now = os.clock()
    local fireInterval = math.max(fireRate or 0.09, 0.04)
    if now - state.lastTriggerShot < fireInterval then
        return
    end

    if mouse1click then
        pcall(mouse1click)
        state.lastTriggerShot = now
    elseif mouse1press and mouse1release then
        state.lastTriggerShot = now
        pcall(mouse1press)
        task.delay(0.02, function()
            pcall(mouse1release)
        end)
    end
end

local function updateCombatState(dt)
    if not state.combatEnabled then
        state.selectedTarget = nil
        state.combatStatus = "待机"
        return
    end

    local weaponCtx = getCurrentWeaponContext()
    state.currentWeapon = weaponCtx.object
    state.currentEquippedToolName = weaponCtx.name
    state.currentWeaponStats = weaponCtx.itemSettings
    state.currentAmmoStats = weaponCtx.ammoAttrs
    local hasWeaponProfile = readWeaponValue(weaponCtx, "FireRate", nil) ~= nil

    local targetInfo, reason = chooseMergedCombatTarget()
    if not targetInfo then
        state.selectedTarget = nil
        state.combatStatus = reason or "未找到有效目标"
        return
    end

    state.selectedTarget = targetInfo
    if not state.npcLockEnabled and not state.autoSelectClosest then
        state.targetName = targetInfo.name
    end
    state.combatStatus = string.format(
        "锁定 %s | %.1fm | %s",
        targetInfo.name,
        targetInfo.distance,
        targetInfo.visible and "可见" or "遮挡"
    )
    if not hasWeaponProfile then
        state.combatStatus = state.combatStatus .. " | 基础锁定"
    end

    if state.lockCamera then
        local camera = Workspace.CurrentCamera
        if camera and targetInfo.aimPart then
            local muzzleVelocity = readAmmoValue(weaponCtx, "MuzzleVelocity", 1500)
            local projectileDrop = readAmmoValue(weaponCtx, "ProjectileDrop", 0)
            local distance = (camera.CFrame.Position - targetInfo.aimPart.Position).Magnitude
            local travelTime = distance / math.max(muzzleVelocity, 1)
            local lead = targetInfo.velocity * travelTime
            local dropComp = Vector3.new(0, projectileDrop * travelTime * travelTime * 0.5, 0)
            local predicted = targetInfo.aimPart.Position + lead + dropComp
            local alpha = math.clamp(state.aimSmoothness * (dt * 60), 0.04, 0.95)
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.new(camera.CFrame.Position, predicted),
                alpha
            )
        end
    end

    attemptTriggerShot(targetInfo)
end

local function renderOverview()
    clearBody(refs.overview.summary)
    clearBody(refs.overview.status)
    clearBody(refs.overview.quest)

    local factionNote = "派系模块: "
    if cachedModules.FactionRelations and type(cachedModules.FactionRelations.getAllies) == "function" then
        local allies = cachedModules.FactionRelations.getAllies("Wastelanders")
        factionNote = factionNote .. "已载入，荒原者盟友 " .. tostring(#allies) .. " 个"
    else
        factionNote = factionNote .. "未载入"
    end

    local summaryLines = {
        "<b>已验证机制</b>",
        "1. 任务系统由任务模块驱动，包含<b>每日</b>与<b>每周</b>两类，目标已看到<b>消灭</b>与<b>上交</b>。",
        "2. 地图内的任务角色就是服务入口，当前客户端已识别多名服务角色与功能入口。",
        "3. <b>制作</b>与<b>建造</b>已存在完整系统：医疗、弹药、陷阱、路障、消音器、建造预览与碰撞校验。",
        "4. 网络层已发现<b>" .. tostring(#state.scans.remotes.events) .. " 个事件</b>与<b>" .. tostring(#state.scans.remotes.functions) .. " 个函数</b>，覆盖搜刮、商人、制作、建造、投射物、交易、传送。",
        "5. 当前地图更像<b>灾后生存 + 派系角色 + 容器搜刮 + 改装制作 + 玩家对抗</b>的复合循环，而不是单线战斗图。",
        factionNote
    }
    makeParagraph(refs.overview.summary, table.concat(summaryLines, "\n"), theme.text)

    local rsPlayer = getRsPlayer()
    local gameplay = rsPlayer and rsPlayer:FindFirstChild("Status")
        and rsPlayer.Status:FindFirstChild("GameplayVariables")
    local attributes = gameplay and gameplay:GetAttributes() or {}
    local ordered = {
        "Loaded", "Spawned", "GodMode", "Drowning", "Aiming", "Stance",
        "VendorCooldown", "Respawns", "CanRevive", "Invisible", "BuildingDebounce"
    }
    for _, key in ipairs(ordered) do
        makeRow(refs.overview.status, fieldText(key), visibleValueText(attributes[key]), {})
    end

    for index, npc in ipairs(state.scans.npcs) do
        if index > 12 then
            break
        end
        local questText = npc.hasQuest and "有任务" or "空闲"
        local color = npc.hasQuest and theme.success or theme.warn
        makeRow(refs.overview.quest, npc.name, questText .. " | " .. roundNumber(npc.distance) .. "m", {
            {
                text = "传送",
                color = color,
                callback = function()
                    teleportToPosition(npc.position)
                    setLastAction("传送到角色: " .. npc.name)
                end
            }
        })
    end
end

local function renderWorld()
    clearBody(refs.world.npcs)
    clearBody(refs.world.containers)
    clearBody(refs.world.prompts)

    for index, npc in ipairs(state.scans.npcs) do
        if index > 18 then
            break
        end
        local detail = (npc.hasQuest and "有任务" or "无任务")
            .. " | " .. roundNumber(npc.distance) .. "m | " .. formatVector3(npc.position)
        makeRow(refs.world.npcs, npc.name, detail, {
            {
                text = "传送",
                color = theme.accent,
                callback = function()
                    teleportToPosition(npc.position)
                    setLastAction("传送到角色: " .. npc.name)
                end
            }
        })
    end

    for index, container in ipairs(state.scans.containers) do
        if index > 20 then
            break
        end
        makeRow(refs.world.containers, container.id, roundNumber(container.distance) .. "m | " .. formatVector3(container.position), {
            {
                text = "传送",
                color = theme.warn,
                callback = function()
                    teleportToPosition(container.position)
                    setLastAction("传送到容器: " .. container.id)
                end
            }
        })
    end

    for index, promptInfo in ipairs(state.scans.prompts) do
        if index > 28 then
            break
        end
        local label = (promptInfo.actionText ~= "" and promptInfo.actionText or "交互点")
            .. " / " .. (promptInfo.objectText ~= "" and promptInfo.objectText or promptInfo.prompt.Name)
        local detail = roundNumber(promptInfo.distance) .. "m | " .. (promptInfo.enabled and "已启用" or "已禁用")
        makeRow(refs.world.prompts, label, detail, {
            {
                text = "传送",
                color = theme.accentAlt,
                callback = function()
                    teleportToPosition(promptInfo.position)
                    setLastAction("传送到提示: " .. label)
                end
            },
            {
                text = "触发",
                color = theme.success,
                callback = function()
                    firePrompt(promptInfo.prompt)
                end
            }
        })
    end
end

local function renderPlayers()
    clearBody(refs.players.list)
    clearBody(refs.players.camera)

    if #state.scans.players == 0 then
        makeParagraph(refs.players.list, "当前没有其他在线玩家。")
    else
        for index, playerInfo in ipairs(state.scans.players) do
            if index > 20 then
                break
            end
            local detail = string.format(
                "%sm | %s | 血量 %.0f/%.0f",
                roundNumber(playerInfo.distance),
                playerInfo.team,
                playerInfo.health,
                playerInfo.maxHealth
            )
            makeRow(refs.players.list, playerInfo.name, detail, {
                {
                    text = "传送",
                    color = theme.player,
                    callback = function()
                        teleportToPosition(playerInfo.position)
                        setLastAction("传送到玩家: " .. playerInfo.name)
                    end
                },
                {
                    text = "观战",
                    color = theme.accent,
                    callback = function()
                        focusCharacter(playerInfo.player)
                    end
                }
            })
        end
    end

    local character = getCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local currentPos = root and formatVector3(root.Position) or "无"
    makeParagraph(refs.players.camera, "当前位置: <b>" .. currentPos .. "</b>", theme.text)
    makeRow(refs.players.camera, "镜头控制", "恢复本体视角或跳到当前扫描目标", {
        {
            text = "恢复",
            color = theme.success,
            callback = restoreCamera
        }
    })
end

local function renderNetwork()
    clearBody(refs.network.summary)
    clearBody(refs.network.events)
    clearBody(refs.network.functions)
    clearBody(refs.network.logs)

    local summaryText = table.concat({
        "事件: " .. tostring(#state.scans.remotes.events),
        "函数: " .. tostring(#state.scans.remotes.functions),
        "记录: " .. toggleText(state.remoteHookEnabled),
        "状态: " .. state.hookStatus,
        "日志: " .. tostring(#state.remoteLogs)
    }, " | ")
    makeParagraph(refs.network.summary, "<b>" .. summaryText .. "</b>", theme.text)
    makeRow(refs.network.summary, "远程钩子", state.remoteHookEnabled and "正在记录客户端调用" or "当前未记录", {
        {
            text = state.remoteHookEnabled and "停止" or "启动",
            color = state.remoteHookEnabled and theme.danger or theme.success,
            callback = function()
                if state.remoteHookEnabled then
                    state.remoteHookEnabled = false
                    state.hookStatus = "已暂停"
                else
                    if installRemoteHook() then
                        state.remoteHookEnabled = true
                        state.hookStatus = "正在记录"
                    end
                end
                setLastAction("远程记录 -> " .. toggleText(state.remoteHookEnabled))
                renderNetwork()
            end
        },
        {
            text = "清空",
            color = theme.panel,
            callback = function()
                table.clear(state.remoteLogs)
                setLastAction("已清空远程日志")
                renderNetwork()
            end
        }
    })

    for _, remote in ipairs(state.scans.remotes.events) do
        makeRow(refs.network.events, remote.Name, modeText(remote.ClassName), {})
    end

    for _, remote in ipairs(state.scans.remotes.functions) do
        makeRow(refs.network.functions, remote.Name, modeText(remote.ClassName), {})
    end

    if #state.remoteLogs == 0 then
        makeParagraph(refs.network.logs, "暂无日志。开启远程记录后，在地图里进行交互、开箱、接任务、切换武器或移动物品即可采样。")
    else
        for index, entry in ipairs(state.remoteLogs) do
            if index > 36 then
                break
            end
            local detail = string.format(
                "%.2f | %s | %s | %s",
                entry.t,
                entry.method,
                entry.source,
                entry.args
            )
            makeRow(refs.network.logs, entry.name, detail, {})
        end
    end
end

local function renderCombat()
    clearBody(refs.combat.target)
    clearBody(refs.combat.weapon)
    clearBody(refs.combat.tools)

    local selected = getNamedTarget()
    local selectedNpc = getNamedNpcTarget()
    local activeTargetName = state.selectedTarget and state.selectedTarget.name or nil
    local weaponName = state.currentEquippedToolName or "无"
    local ammo = state.currentAmmoStats
    local currentTargetName = activeTargetName
        or (selected and selected.name)
        or state.targetName
        or state.selectedNpcName
        or "-"
    local summary = string.format(
        "作战 %s | 镜头跟踪 %s | 扳机辅助 %s | 锁定圈 %.0f | 最远 %.0f | 当前目标：%s",
        toggleText(state.combatEnabled),
        toggleText(state.lockCamera),
        toggleText(state.triggerBot),
        state.combatFov,
        state.combatMaxDistance,
        currentTargetName
    )
    makeParagraph(refs.combat.target, "<b>" .. summary .. "</b>", theme.text)
    makeParagraph(refs.combat.target, "状态: " .. state.combatStatus .. " | 优先级: " .. state.targetPriorityMode, theme.subtext)
    makeRow(refs.combat.target, "NPC目标", selectedNpc and ("优先目标：" .. selectedNpc.name .. "，锁定池里仍然保留玩家目标") or "未指定优先NPC，开启后会把全部非玩家角色加入锁定池", {
        {
            text = "清空",
            color = theme.panel,
            callback = function()
                clearSelectedNpcTarget()
                setLastAction("已清空NPC优先目标")
                renderCombat()
            end
        }
    })

    if #state.scans.npcs > 0 then
        makeParagraph(refs.combat.target, "<b>可选角色</b>", theme.text)
        local shownNpcs = 0
        for _, npcInfo in ipairs(state.scans.npcs) do
            if shownNpcs >= 10 then
                break
            end
            local npcCombat = buildNpcCombatInfo(npcInfo)
            if npcCombat then
                shownNpcs += 1
                local npcDetail = string.format(
                    "%.1fm | %s | 屏距 %.0f | %s",
                    npcCombat.distance,
                    npcInfo.hasHint and npcInfo.hasQuest and "有任务" or (npcInfo.hasHint and "无任务" or "数据角色"),
                    npcCombat.screenDistance,
                    npcCombat.onScreen and (npcCombat.visible and "可见" or "遮挡") or "屏外"
                )
                makeRow(refs.combat.target, npcCombat.name, npcDetail, {
                    {
                        text = state.selectedNpcName == npcCombat.name and "已选" or "选择",
                        color = state.selectedNpcName == npcCombat.name and theme.success or theme.warn,
                        callback = function()
                            if state.selectedNpcName == npcCombat.name then
                                clearSelectedNpcTarget()
                                setLastAction("取消NPC优先目标: " .. npcCombat.name)
                            else
                                selectNpcTarget(npcCombat)
                                setLastAction("设置NPC优先目标: " .. npcCombat.name)
                            end
                            renderCombat()
                        end
                    }
                })
            end
        end
    end

    makeParagraph(refs.combat.target, "<b>玩家目标</b>", theme.text)

    local shown = 0
    for _, playerInfo in ipairs(state.scans.players) do
        if shown >= 12 then
            break
        end
        local combatInfo = buildCombatInfo(playerInfo)
        if combatInfo then
            shown += 1
            local detail = string.format(
                "%.1fm | %s | 屏距 %.0f | 血量 %.0f/%.0f | %s",
                combatInfo.distance,
                combatInfo.team,
                combatInfo.screenDistance,
                combatInfo.health,
                combatInfo.maxHealth,
                combatInfo.visible and "可见" or "遮挡"
            )
            makeRow(refs.combat.target, combatInfo.name, detail, {
                {
                    text = state.targetName == combatInfo.name and "已选" or "选择",
                    color = state.targetName == combatInfo.name and theme.success or theme.accent,
                    callback = function()
                        selectTarget(combatInfo)
                        setLastAction("选中战斗目标: " .. combatInfo.name)
                        renderCombat()
                    end
                },
                {
                    text = "观战",
                    color = theme.panel,
                    callback = function()
                        focusCharacter(combatInfo.player)
                    end
                }
            })
        end
    end

    local weaponCtx = state.scans.weapons
    local weaponStats = state.currentWeaponStats
    local weaponAttrs = weaponCtx and weaponCtx.weaponAttrs or nil
    if not weaponName then
        makeParagraph(refs.combat.weapon, "当前未持有远程武器。先装备枪械，战斗页会自动读取“射速 / 开火模式 / 默认弹药 / 初速”等数据。")
    else
        local detail = {
            "武器: " .. weaponName,
            "模式: " .. visibleValueText((weaponStats and weaponStats.FireMode) or (weaponAttrs and weaponAttrs.FireMode) or nil),
            "射速: " .. visibleValueText(readWeaponValue(weaponCtx, "FireRate", nil)),
            "后坐力: " .. visibleValueText(readWeaponValue(weaponCtx, "MaxRecoil", nil)),
            "弹药: " .. visibleValueText(ammo and ammo.CallSign or nil),
            "初速: " .. visibleValueText(readAmmoValue(weaponCtx, "MuzzleVelocity", ammo and ammo.MuzzleVelocity or nil)),
            "伤害: " .. visibleValueText(ammo and ammo.Damage or nil),
            "穿甲: " .. visibleValueText(ammo and ammo.ArmorPen or nil)
        }
        makeParagraph(refs.combat.weapon, table.concat(detail, "\n"), theme.text)
    end

    makeRow(refs.combat.tools, "战斗总开关", "启用后按当前设定做目标选择与战斗辅助", {
        {
            text = toggleText(state.combatEnabled),
            color = state.combatEnabled and theme.success or theme.panel,
            callback = function()
                state.combatEnabled = not state.combatEnabled
                if not state.combatEnabled then
                    state.selectedTarget = nil
                    state.combatStatus = "待机"
                end
                updateLockCircle()
                setLastAction("作战总开关 -> " .. toggleText(state.combatEnabled))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "锁定NPC", "开启后把全部非玩家角色加入锁定池，玩家目标仍然会照常参与锁定", {
        {
            text = toggleText(state.npcLockEnabled),
            color = state.npcLockEnabled and theme.success or theme.panel,
            callback = function()
                state.npcLockEnabled = not state.npcLockEnabled
                state.selectedTarget = nil
                if not state.npcLockEnabled then
                    state.combatStatus = "NPC锁定已关闭"
                end
                updateLockCircle()
                setLastAction("锁定NPC -> " .. toggleText(state.npcLockEnabled))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "锁定优先级", "可切换为优先玩家、优先NPC、距离优先、准星优先", {
        {
            text = state.targetPriorityMode,
            color = theme.accentAlt,
            width = 108,
            callback = function()
                state.targetPriorityMode = getNextTargetPriorityMode()
                state.selectedTarget = nil
                setLastAction("锁定优先级 -> " .. state.targetPriorityMode)
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "目标选择", "自动模式按自瞄圈筛选，手动选中后可直接强锁", {
        {
            text = state.autoSelectClosest and "自动" or "手动",
            color = state.autoSelectClosest and theme.success or theme.panel,
            callback = function()
                state.autoSelectClosest = not state.autoSelectClosest
                if state.autoSelectClosest then
                    clearSelectedTarget()
                end
                setLastAction("目标模式 -> " .. (state.autoSelectClosest and "自动" or "手动"))
                renderCombat()
            end
        },
        {
            text = "清空",
            color = theme.panel,
            callback = function()
                clearSelectedTarget()
                setLastAction("已清空手动目标")
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "隔墙不锁", "目标被建筑或掩体遮挡时不跟踪", {
        {
            text = toggleText(state.requireVisible),
            color = state.requireVisible and theme.success or theme.panel,
            callback = function()
                state.requireVisible = not state.requireVisible
                state.selectedTarget = nil
                setLastAction("隔墙不锁 -> " .. toggleText(state.requireVisible))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "自瞄圈显示", "自瞄圈独立显示，不受主面板切页影响", {
        {
            text = toggleText(state.showFovCircle),
            color = state.showFovCircle and theme.success or theme.panel,
            callback = function()
                state.showFovCircle = not state.showFovCircle
                updateLockCircle()
                setLastAction("自瞄圈显示 -> " .. toggleText(state.showFovCircle))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "镜头跟踪", "把摄像机平滑拉到预测点", {
        {
            text = toggleText(state.lockCamera),
            color = state.lockCamera and theme.success or theme.panel,
            callback = function()
                state.lockCamera = not state.lockCamera
                setLastAction("镜头跟踪 -> " .. toggleText(state.lockCamera))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "扳机辅助", "目标进入小窗口时自动点射", {
        {
            text = toggleText(state.triggerBot),
            color = state.triggerBot and theme.success or theme.panel,
            callback = function()
                state.triggerBot = not state.triggerBot
                setLastAction("扳机辅助 -> " .. toggleText(state.triggerBot))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "目标部位", "当前优先部位: " .. modeText(state.targetPart), {
        {
            text = "切换",
            color = theme.accentAlt,
            callback = function()
                if state.targetPart == "Head" then
                    state.targetPart = "UpperTorso"
                elseif state.targetPart == "UpperTorso" then
                    state.targetPart = "HumanoidRootPart"
                else
                    state.targetPart = "Head"
                end
                setLastAction("目标部位 -> " .. modeText(state.targetPart))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "后坐力补丁", "动态把各枪械设置表中的后坐与枪口晃动压到最低", {
        {
            text = toggleText(state.recoilPatch),
            color = state.recoilPatch and theme.success or theme.panel,
            callback = function()
                state.recoilPatch = not state.recoilPatch
                applyRecoilPatch(state.recoilPatch)
                setLastAction("后坐力补丁 -> " .. toggleText(state.recoilPatch))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "锁定圈范围", "自动找目标按圈筛选，手动和NPC强锁不受这项限制", {
        {
            text = "-",
            color = theme.panel,
            width = 34,
            callback = function()
                state.combatFov = math.max(60, state.combatFov - 20)
                updateLockCircle()
                setLastAction("锁定圈范围 -> " .. tostring(state.combatFov))
                renderCombat()
            end
        },
        {
            text = tostring(math.floor(state.combatFov)),
            color = theme.panelAlt,
            width = 54
        },
        {
            text = "+",
            color = theme.panel,
            width = 34,
            callback = function()
                state.combatFov = math.min(420, state.combatFov + 20)
                updateLockCircle()
                setLastAction("锁定圈范围 -> " .. tostring(state.combatFov))
                renderCombat()
            end
        }
    })

    makeRow(refs.combat.tools, "最远距离", "目标超出这个距离时不再锁定", {
        {
            text = "-",
            color = theme.panel,
            width = 34,
            callback = function()
                state.combatMaxDistance = math.max(80, state.combatMaxDistance - 20)
                setLastAction("最远距离 -> " .. tostring(state.combatMaxDistance))
                renderCombat()
            end
        },
        {
            text = tostring(math.floor(state.combatMaxDistance)),
            color = theme.panelAlt,
            width = 54
        },
        {
            text = "+",
            color = theme.panel,
            width = 34,
            callback = function()
                state.combatMaxDistance = math.min(1200, state.combatMaxDistance + 20)
                setLastAction("最远距离 -> " .. tostring(state.combatMaxDistance))
                renderCombat()
            end
        }
    })
end

local function renderActions()
    clearBody(refs.actions.toggles)
    clearBody(refs.actions.travel)
    clearBody(refs.actions.utility)

    local toggleRows = {
        {
            label = "角色高亮",
            detail = "高亮任务与服务角色",
            key = "npcEsp"
        },
        {
            label = "容器高亮",
            detail = "高亮地图容器",
            key = "containerEsp"
        },
        {
            label = "交互点高亮",
            detail = "高亮可交互提示",
            key = "promptEsp"
        },
        {
            label = "玩家高亮",
            detail = "高亮其他在线玩家",
            key = "playerEsp"
        }
    }

    for _, row in ipairs(toggleRows) do
        makeRow(refs.actions.toggles, row.label, row.detail, {
            {
                text = toggleText(state[row.key]),
                color = state[row.key] and theme.success or theme.panel,
                callback = function()
                    state[row.key] = not state[row.key]
                    refreshMarkers()
                    renderActions()
                    setLastAction(row.label .. " -> " .. toggleText(state[row.key]))
                end
            }
        })
    end

    for name, position in pairs(state.scans.anchors) do
        makeRow(refs.actions.travel, name, formatVector3(position), {
            {
                text = "传送",
                color = theme.accent,
                callback = function()
                    teleportToPosition(position)
                    setLastAction("传送到锚点: " .. name)
                end
            }
        })
    end

    if state.scans.containers[1] then
        makeRow(refs.actions.travel, "最近容器", state.scans.containers[1].id .. " | " .. roundNumber(state.scans.containers[1].distance) .. "m", {
            {
                text = "前往",
                color = theme.warn,
                callback = function()
                    teleportToPosition(state.scans.containers[1].position)
                    setLastAction("前往最近容器")
                end
            }
        })
    end

    makeRow(refs.actions.utility, "刷新扫描", "重扫角色 / 容器 / 交互点 / 玩家 / 远程对象", {
        {
            text = "刷新",
            color = theme.success,
            callback = function()
                refreshScans()
                setLastAction("已刷新扫描")
            end
        }
    })

    makeRow(refs.actions.utility, "恢复摄像机", "把视角主体拉回本体", {
        {
            text = "恢复",
            color = theme.accentAlt,
            callback = restoreCamera
        }
    })

    makeRow(refs.actions.utility, "远程记录", "切换本地远程调用记录", {
        {
            text = state.remoteHookEnabled and "停止" or "启动",
            color = state.remoteHookEnabled and theme.danger or theme.success,
            callback = function()
                if state.remoteHookEnabled then
                    state.remoteHookEnabled = false
                    state.hookStatus = "已暂停"
                else
                    if installRemoteHook() then
                        state.remoteHookEnabled = true
                        state.hookStatus = "正在记录"
                    end
                end
                setLastAction("远程记录 -> " .. toggleText(state.remoteHookEnabled))
                renderActions()
            end
        }
    })
end

local renderers = {
    ["概览"] = renderOverview,
    ["场景"] = renderWorld,
    ["玩家"] = renderPlayers,
    ["网络"] = renderNetwork,
    ["战斗"] = renderCombat,
    ["动作"] = renderActions
}

local function renderCurrentPage()
    local renderer = renderers[state.currentPage]
    if renderer then
        renderer()
    end
end

local function updateFooter()
    local character = getCharacter()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rsPlayer = getRsPlayer()
    local gameplay = rsPlayer and rsPlayer:FindFirstChild("Status")
        and rsPlayer.Status:FindFirstChild("GameplayVariables")
    local mode = getGameMode()
    local position = root and formatVector3(root.Position) or "无"
    local hp = humanoid and string.format("%.0f/%.0f", humanoid.Health, humanoid.MaxHealth) or "无"
    local stance = gameplay and visibleValueText(gameplay:GetAttribute("Stance")) or "无"
    local combatTarget = state.selectedTarget and state.selectedTarget.name or state.targetName or "-"
    if state.npcLockEnabled then
        combatTarget = state.selectedNpcName or combatTarget
    end

    footerLeft.Text = string.format(
        "模式 %s | 血量 %s | 姿态 %s | 坐标 %s | 角色 %d | 交互点 %d | 目标 %s | 最近操作：%s",
        tostring(mode),
        hp,
        stance,
        position,
        #state.scans.npcs,
        #state.scans.prompts,
        combatTarget,
        state.lastAction
    )
end

local function cleanup()
    if not state.alive then
        return
    end
    state.alive = false
    if state.recoilPatch then
        applyRecoilPatch(false)
    end
    pcall(restoreCamera)
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for key in pairs(state.markers) do
        removeMarker(key)
    end
    markerFolder:Destroy()
    fovGui:Destroy()
    screenGui:Destroy()
end

local dragging = false
local dragStart
local startPosition
local viewportSizeConnection

local function bindViewportSizeListener()
    if viewportSizeConnection then
        pcall(function()
            viewportSizeConnection:Disconnect()
        end)
        viewportSizeConnection = nil
    end

    local camera = Workspace.CurrentCamera
    if camera then
        viewportSizeConnection = pushConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout))
    end
end

pushConnection(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end))

pushConnection(topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

pushConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

pushConnection(closeButton.MouseButton1Click:Connect(cleanup))

pushConnection(collapseButton.MouseButton1Click:Connect(function()
    state.collapsed = not state.collapsed
    contentHolder.Visible = not state.collapsed
    leftRail.Visible = not state.collapsed
    footer.Visible = not state.collapsed
    syncMainSize()
    collapseButton.Text = state.collapsed and "+" or "-"
    updateLockCircle()
    setLastAction(state.collapsed and "面板已折叠" or "面板已展开")
end))

pushConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    bindViewportSizeListener()
    applyResponsiveLayout()
end))

pushConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        state.hidden = not state.hidden
        screenGui.Enabled = not state.hidden
        updateLockCircle()
    elseif input.KeyCode == Enum.KeyCode.End then
        cleanup()
    end
end))

bindViewportSizeListener()
syncMainSize()

pushConnection(RunService.RenderStepped:Connect(function(dt)
    if state.alive then
        pcall(updateCombatState, dt)
    end
end))

local function protectedStep(stepName, callback)
    local ok, err = pcall(callback)
    if not ok then
        setLastAction(stepName .. "失败")
        warn("[三角洲作战控制台] " .. stepName .. "失败: " .. tostring(err))
        return false
    end
    return true
end

protectedStep("初始扫描", refreshScans)
protectedStep("概览渲染", renderOverview)
protectedStep("场景渲染", renderWorld)
protectedStep("玩家渲染", renderPlayers)
protectedStep("网络渲染", renderNetwork)
protectedStep("战斗渲染", renderCombat)
protectedStep("动作渲染", renderActions)
protectedStep("页脚渲染", updateFooter)
setLastAction("扫描完成")
protectedStep("锁定圈刷新", updateLockCircle)
protectedStep("当前页渲染", renderCurrentPage)

task.spawn(function()
    while state.alive do
        protectedStep("扫描刷新", refreshScans)
        protectedStep("页面刷新", renderCurrentPage)
        protectedStep("页脚刷新", updateFooter)
        protectedStep("锁定圈刷新", updateLockCircle)
        task.wait(1.25)
    end
end)

task.spawn(function()
    while state.alive do
        pcall(updateFooter)
        task.wait(0.2)
    end
end)
