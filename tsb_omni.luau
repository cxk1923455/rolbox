--[[
   █████╗ ██████╗ ███████╗██╗  ██╗    ██████╗ ███╗   ███╗███╗   ██╗██╗
  ██╔══██╗██╔══██╗██╔════╝╚██╗██╔╝   ██╔═══██╗████╗ ████║████╗  ██║██║
  ███████║██████╔╝█████╗   ╚███╔╝    ██║   ██║██╔████╔██║██╔██╗ ██║██║
  ██╔══██║██╔═══╝ ██╔══╝   ██╔██╗    ██║   ██║██║╚██╔╝██║██║╚██╗██║██║
  ██║  ██║██║     ███████╗██╔╝ ██╗   ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║
  ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝
  最强战场 · APEX OMNI  ——  AI 全自动战斗大脑 (Client-Side)
  M1/技能/格挡 = VirtualInputManager 真实输入 · 读属性预判 · 状态机决策
]]

if getgenv and getgenv().__APEX_HUB then pcall(function() getgenv().__APEX_HUB:Destroy() end) end

--==================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local VIM               = game:GetService("VirtualInputManager")

local LP    = Players.LocalPlayer
local Cam   = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

--==================================================================
-- 状态
--==================================================================
local State = {
    -- AI 大脑
    AIBrain     = false,
    UseSkills   = true,
    AutoLauncher= true,
    BlockBreak  = true,
    SkillDodge  = true,
    AutoUlt     = true,
    AutoEscape  = true,
    EscapeHP    = 25,
    -- 基础战斗
    AutoCombo    = false,
    AutoBlock    = false,
    ReactiveParry= true,
    HitboxTP     = false,
    AutoApproach = true,
    AutoFace     = true,
    PlayersOnly  = true,
    FightRange   = 80,
    ComboReach   = 14,
    -- 移动
    Fly=false, FlySpeed=60, Noclip=false, InfJump=false,
    WalkSpeed=16, JumpPower=45, SpeedLock=false,
    -- 视觉/其他
    ESP=false, ESPDist=true, Fullbright=false,
    AntiRag=false, AntiVoid=false, AntiAFK=true,
}

-- 实时 HUD / 大脑决策(供界面显示)
local HUD = { state="待机", target="无", dist=0, combo=0, action="—", threat="低" }

local Connections = {}
local function bind(n, c) Connections[n] = c end

local function getChar()
    local c = LP.Character; if not c then return end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

--==================================================================
-- 主题 & 组件工厂
--==================================================================
local T = {
    bg=Color3.fromRGB(14,14,20), bg2=Color3.fromRGB(22,22,32), card=Color3.fromRGB(30,30,44),
    stroke=Color3.fromRGB(55,55,82), text=Color3.fromRGB(236,236,246), dim=Color3.fromRGB(150,150,172),
    accentA=Color3.fromRGB(140,90,255), accentB=Color3.fromRGB(0,210,255),
    on=Color3.fromRGB(90,235,160), off=Color3.fromRGB(64,64,90),
    warn=Color3.fromRGB(255,170,80), danger=Color3.fromRGB(255,85,110),
}
local function new(cls, props, kids)
    local o = Instance.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    for _,c in ipairs(kids or {}) do c.Parent=o end
    return o
end
local function corner(r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8)}) end
local function stroke(c,t) return new("UIStroke",{Color=c or T.stroke,Thickness=t or 1,Transparency=0.15}) end
local function pad(p) return new("UIPadding",{PaddingTop=UDim.new(0,p),PaddingBottom=UDim.new(0,p),PaddingLeft=UDim.new(0,p),PaddingRight=UDim.new(0,p)}) end
local function grad(rot,a,b) return new("UIGradient",{Color=ColorSequence.new(a or T.accentA,b or T.accentB),Rotation=rot or 0}) end

--==================================================================
-- 根 & 主面板(新光效:去掉外圈光晕 → 柔和投影 + 霓虹描边 + 底部辉光)
--==================================================================
local ScreenGui = new("ScreenGui",{Name="APEX_OMNI",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true})
pcall(function() ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end
if getgenv then getgenv().__APEX_HUB=ScreenGui; getgenv().__APEX_STATE=State end

local Main = new("Frame",{Name="Main",Parent=ScreenGui,Size=UDim2.fromOffset(600,410),
    Position=UDim2.new(0.5,-300,0.5,-205),BackgroundColor3=T.bg,BorderSizePixel=0},{corner(16)})

-- 柔和投影(向下,营造悬浮层次,不是彩色光圈)
new("ImageLabel",{Parent=Main,BackgroundTransparency=1,ZIndex=0,
    Image="rbxassetid://6015897843",ImageColor3=Color3.new(0,0,0),ImageTransparency=0.35,
    Size=UDim2.new(1,48,1,52),Position=UDim2.new(0,-24,0,-18),ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450)})
-- 底部霓虹辉光(细窄,一条,不是四周一圈)
local underGlow = new("Frame",{Parent=Main,BackgroundColor3=T.accentA,BorderSizePixel=0,ZIndex=0,
    Size=UDim2.new(0.7,0,0,4),Position=UDim2.new(0.15,0,1,-2)},{corner(4),
    grad(0,T.accentA,T.accentB)})
new("UIStroke",{Parent=underGlow,Color=T.accentB,Thickness=0}) -- 占位
-- 霓虹渐变描边(紧贴,2px,动画)
local neon = new("UIStroke",{Parent=Main,Thickness=1.6,Transparency=0,Color=Color3.new(1,1,1)})
local neonGrad = grad(0); neonGrad.Parent = neon
-- 顶部内高光
new("Frame",{Parent=Main,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.9,BorderSizePixel=0,
    Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,0,1)})

--==================================================================
-- 顶栏
--==================================================================
local Top = new("Frame",{Name="Top",Parent=Main,Size=UDim2.new(1,0,0,48),BackgroundColor3=T.bg2,BorderSizePixel=0},{corner(16)})
new("Frame",{Parent=Top,Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,1,-16),BackgroundColor3=T.bg2,BorderSizePixel=0})
local Logo = new("Frame",{Parent=Top,Size=UDim2.fromOffset(28,28),Position=UDim2.new(0,16,0.5,-14),BackgroundColor3=Color3.new(1,1,1)},{corner(8),grad(45)})
new("TextLabel",{Parent=Logo,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.GothamBlack,Text="A",TextColor3=T.bg,TextSize=16})
local Title = new("TextLabel",{Parent=Top,BackgroundTransparency=1,Position=UDim2.new(0,56,0,5),Size=UDim2.new(1,-180,0,20),Font=Enum.Font.GothamBlack,TextSize=19,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text="APEX OMNI"})
new("TextLabel",{Parent=Top,BackgroundTransparency=1,Position=UDim2.new(0,56,0,25),Size=UDim2.new(1,-180,0,15),Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=T.dim,TextXAlignment=Enum.TextXAlignment.Left,Text="AI 战斗大脑 · 最强战场"})
do local g=grad(0); g.Parent=Title
   task.spawn(function() while Title.Parent do TweenService:Create(g,TweenInfo.new(3,Enum.EasingStyle.Linear),{Offset=Vector2.new(1,0)}):Play(); task.wait(3); g.Offset=Vector2.new(-1,0) end end) end

local function topBtn(txt,x,col)
    return new("TextButton",{Parent=Top,Size=UDim2.fromOffset(28,28),Position=UDim2.new(1,x,0.5,-14),BackgroundColor3=T.card,Text=txt,TextColor3=col or T.text,Font=Enum.Font.GothamBold,TextSize=16},{corner(8),stroke()})
end
local MinBtn=topBtn("—",-84,T.dim)
local CloseBtn=topBtn("✕",-44,T.danger)

--==================================================================
-- 侧栏 + 内容
--==================================================================
local Body = new("Frame",{Parent=Main,BackgroundTransparency=1,Position=UDim2.new(0,0,0,48),Size=UDim2.new(1,0,1,-48)})
local Side = new("Frame",{Parent=Body,BackgroundColor3=T.bg2,BorderSizePixel=0,Size=UDim2.new(0,148,1,0)})
new("UIListLayout",{Parent=Side,Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
new("UIPadding",{Parent=Side,PaddingTop=UDim.new(0,12)})
local Content = new("Frame",{Parent=Body,BackgroundTransparency=1,Position=UDim2.new(0,148,0,0),Size=UDim2.new(1,-148,1,0)})

local Pages,Tabs={},{}
local function makePage(name)
    local sc=new("ScrollingFrame",{Parent=Content,Visible=false,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.accentA,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},{pad(14)})
    new("UIListLayout",{Parent=sc,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
    Pages[name]=sc; return sc
end
local function selectTab(name)
    for n,p in pairs(Pages) do p.Visible=(n==name) end
    for n,b in pairs(Tabs) do
        TweenService:Create(b,TweenInfo.new(0.2),{BackgroundColor3=(n==name) and T.card or T.bg2,TextColor3=(n==name) and T.text or T.dim}):Play()
        local s=b:FindFirstChildOfClass("UIStroke"); if s then TweenService:Create(s,TweenInfo.new(0.2),{Transparency=(n==name) and 0 or 1}):Play() end
    end
end
local function makeTab(name,icon)
    local b=new("TextButton",{Parent=Side,Size=UDim2.new(1,-16,0,36),BackgroundColor3=T.bg2,Text="  "..icon.."  "..name,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.dim,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false},{corner(9),stroke(T.accentA,1)})
    b:FindFirstChildOfClass("UIStroke").Transparency=1; Tabs[name]=b
    b.MouseButton1Click:Connect(function() selectTab(name) end); makePage(name); return b
end

--==================================================================
-- 组件
--==================================================================
local function label(p,t) return new("TextLabel",{Parent=p,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),Font=Enum.Font.GothamBold,TextSize=11,TextColor3=T.accentB,TextXAlignment=Enum.TextXAlignment.Left,Text="▎ "..t}) end
local function toggle(p,txt,def,cb)
    local row=new("Frame",{Parent=p,Size=UDim2.new(1,0,0,40),BackgroundColor3=T.card,BorderSizePixel=0},{corner(10),stroke()})
    new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-70,1,0),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=txt})
    local knob=new("Frame",{Parent=row,Size=UDim2.fromOffset(44,22),Position=UDim2.new(1,-56,0.5,-11),BackgroundColor3=def and T.on or T.off},{corner(11)})
    local dot=new("Frame",{Parent=knob,Size=UDim2.fromOffset(16,16),Position=def and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),BackgroundColor3=Color3.new(1,1,1)},{corner(8)})
    local st=def or false
    new("TextButton",{Parent=row,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text=""}).MouseButton1Click:Connect(function()
        st=not st
        TweenService:Create(knob,TweenInfo.new(0.18),{BackgroundColor3=st and T.on or T.off}):Play()
        TweenService:Create(dot,TweenInfo.new(0.18,Enum.EasingStyle.Back),{Position=st and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        pcall(cb,st)
    end)
    return row
end
local function slider(p,txt,mn,mx,def,cb)
    local row=new("Frame",{Parent=p,Size=UDim2.new(1,0,0,52),BackgroundColor3=T.card,BorderSizePixel=0},{corner(10),stroke()})
    new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(0,14,0,6),Size=UDim2.new(1,-28,0,18),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=txt})
    local val=new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(1,-60,0,6),Size=UDim2.new(0,46,0,18),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.accentB,TextXAlignment=Enum.TextXAlignment.Right,Text=tostring(def)})
    local bar=new("Frame",{Parent=row,Position=UDim2.new(0,14,1,-16),Size=UDim2.new(1,-28,0,6),BackgroundColor3=T.bg},{corner(3)})
    local fill=new("Frame",{Parent=bar,BackgroundColor3=Color3.new(1,1,1),Size=UDim2.new((def-mn)/(mx-mn),0,1,0)},{corner(3),grad(0)})
    local drag=false
    local function set(x)
        local rel=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        fill.Size=UDim2.new(rel,0,1,0)
        local v=math.floor((mn+(mx-mn)*rel)*10+0.5)/10; val.Text=tostring(v); pcall(cb,v)
    end
    new("TextButton",{Parent=bar,BackgroundTransparency=1,Size=UDim2.new(1,0,3,0),Position=UDim2.new(0,0,-1,0),Text=""}).MouseButton1Down:Connect(function() drag=true; set(Mouse.X) end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then set(Mouse.X) end end)
    return row
end
local function button(p,txt,cb)
    local b=new("TextButton",{Parent=p,Size=UDim2.new(1,0,0,38),BackgroundColor3=T.card,Text=txt,TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=13,AutoButtonColor=false},{corner(10),stroke(T.accentA,1)})
    b:FindFirstChildOfClass("UIStroke").Transparency=0.4
    b.MouseButton1Click:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=T.accentA}):Play()
        task.delay(0.12,function() TweenService:Create(b,TweenInfo.new(0.2),{BackgroundColor3=T.card}):Play() end); pcall(cb)
    end)
    return b
end

--==================================================================
-- 拖动 / 最小化 / 关闭
--==================================================================
do
    local dragging,ds,sp
    Top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; ds=i.Position; sp=Main.Position end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds; Main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
end
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    TweenService:Create(Main,TweenInfo.new(0.25,Enum.EasingStyle.Quart),{Size=minimized and UDim2.fromOffset(600,48) or UDim2.fromOffset(600,410)}):Play()
    Body.Visible=not minimized; underGlow.Visible=not minimized
end)
CloseBtn.MouseButton1Click:Connect(function()
    for _,c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    TweenService:Create(Main,TweenInfo.new(0.25),{Size=UDim2.fromOffset(0,0),Position=UDim2.new(0.5,0,0.5,0)}):Play()
    task.wait(0.26); ScreenGui:Destroy(); if getgenv then getgenv().__APEX_HUB=nil end
end)

--==================================================================
-- 标签页
--==================================================================
makeTab("AI 大脑","🧠")
makeTab("战斗","⚔️")
makeTab("移动","🏃")
makeTab("视觉","👁️")
makeTab("玩家","🎯")
makeTab("其他","⚙️")

--------------------------------------------------------------------
-- 🧠 AI 大脑页
--------------------------------------------------------------------
local BrainHUD
do
    local pg=Pages["AI 大脑"]
    label(pg,"AI 决策实况")
    local card=new("Frame",{Parent=pg,Size=UDim2.new(1,0,0,96),BackgroundColor3=T.bg2,BorderSizePixel=0},{corner(12),stroke(T.accentB,1.2)})
    new("UIGradient",{Parent=card,Rotation=30,Color=ColorSequence.new(T.bg2,T.card)})
    BrainHUD=new("TextLabel",{Parent=card,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-24,1,0),Font=Enum.Font.Code,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Text="● 大脑离线"})

    label(pg,"主控")
    toggle(pg,"🧠 启动 AI 战斗大脑 (全自动接管)",false,function(s) State.AIBrain=s end)
    label(pg,"大脑能力")
    toggle(pg,"⚡ 用技能连招 (1/2/3/4)",true,function(s) State.UseSkills=s end)
    toggle(pg,"🚀 自动挑空接浮空连 (Uppercut)",true,function(s) State.AutoLauncher=s end)
    toggle(pg,"🔨 拆盾 (对方格挡→Shove 破防)",true,function(s) State.BlockBreak=s end)
    toggle(pg,"🌀 预判闪避技能 (敌人放招→规避)",true,function(s) State.SkillDodge=s end)
    toggle(pg,"💥 自动大招 (SERIOUS MODE)",true,function(s) State.AutoUlt=s end)
    toggle(pg,"🛟 残血自动逃生",true,function(s) State.AutoEscape=s end)
    slider(pg,"逃生血量%",5,60,25,function(v) State.EscapeHP=v end)
    slider(pg,"索敌范围",30,200,80,function(v) State.FightRange=v end)
end

--------------------------------------------------------------------
-- ⚔️ 战斗页
--------------------------------------------------------------------
do
    local pg=Pages["战斗"]
    label(pg,"手动战斗开关 (大脑关闭时生效)")
    toggle(pg,"⚔️ 自动连招 (纯 M1)",false,function(s) State.AutoCombo=s end)
    toggle(pg,"🛡️ 自动格挡 (常驻)",false,function(s) State.AutoBlock=s end)
    label(pg,"通用战术")
    toggle(pg,"⚡ 反应格挡 (帧级 parry)",true,function(s) State.ReactiveParry=s end)
    toggle(pg,"📌 命中盒锁定 (瞬移贴脸)",false,function(s) State.HitboxTP=s end)
    toggle(pg,"🏃 自动接近目标",true,function(s) State.AutoApproach=s end)
    toggle(pg,"🎯 自动面向目标",true,function(s) State.AutoFace=s end)
    toggle(pg,"👤 只锁真人玩家",true,function(s) State.PlayersOnly=s end)
    slider(pg,"连招距离",8,30,14,function(v) State.ComboReach=v end)
    button(pg,"🧍 木桩传到面前 (测试)",function()
        local d=Workspace:FindFirstChild("Live") and Workspace.Live:FindFirstChild("Weakest Dummy")
        local _,_,hrp=getChar(); local dh=d and d:FindFirstChild("HumanoidRootPart")
        if dh and hrp then dh.CFrame=hrp.CFrame*CFrame.new(0,0,-4) end
    end)
    new("TextLabel",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,60),Font=Enum.Font.Gotham,TextSize=11,TextColor3=T.dim,TextWrapped=true,Text="⚡ 全部经 VirtualInputManager 真实输入,服务器判定合法。伤害/命中在服务端,纯客户端无法做真无敌/秒杀,也没有 100% 必胜。"})
end

--------------------------------------------------------------------
-- 🏃 移动页
--------------------------------------------------------------------
do
    local pg=Pages["移动"]
    label(pg,"速度 & 跳跃")
    slider(pg,"行走速度",16,250,16,function(v) State.WalkSpeed=v; local _,h=getChar(); if h then h.WalkSpeed=v end end)
    slider(pg,"跳跃力",45,350,45,function(v) State.JumpPower=v; local _,h=getChar(); if h then h.UseJumpPower=true; h.JumpPower=v end end)
    toggle(pg,"锁定速度(防重置)",false,function(s) State.SpeedLock=s end)
    toggle(pg,"无限跳跃",false,function(s) State.InfJump=s end)
    label(pg,"飞行 & 穿墙")
    toggle(pg,"飞行 (Space/Shift 升降)",false,function(s) State.Fly=s end)
    slider(pg,"飞行速度",20,300,60,function(v) State.FlySpeed=v end)
    toggle(pg,"穿墙 Noclip",false,function(s) State.Noclip=s end)
end

--------------------------------------------------------------------
-- 👁️ 视觉页
--------------------------------------------------------------------
local ESPStore={}
local function clearESP() for _,f in pairs(ESPStore) do pcall(function() f:Destroy() end) end table.clear(ESPStore) end
local function makeESP(plr)
    if plr==LP or ESPStore[plr] then return end
    local f=new("Folder",{})
    local hl=new("Highlight",{Name="Ax",FillColor=T.accentA,OutlineColor=T.accentB,FillTransparency=0.55,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,Parent=f})
    local bb=new("BillboardGui",{Name="Ax",Size=UDim2.fromOffset(160,32),StudsOffset=Vector3.new(0,3.2,0),AlwaysOnTop=true,Parent=f})
    local tl=new("TextLabel",{Parent=bb,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.text,TextStrokeTransparency=0,Text=plr.Name})
    local function attach() local ch=plr.Character; if ch then hl.Parent=ch; bb.Adornee=ch:FindFirstChild("HumanoidRootPart") end end
    attach(); f.tl=tl; ESPStore[plr]=f
    bind("esp_"..plr.Name, plr.CharacterAdded:Connect(function() task.wait(0.4); attach() end))
end
do
    local pg=Pages["视觉"]
    label(pg,"透视 ESP")
    toggle(pg,"启用 ESP (高亮+名字)",false,function(s) State.ESP=s; if s then for _,p in ipairs(Players:GetPlayers()) do makeESP(p) end else clearESP() end end)
    toggle(pg,"显示距离",true,function(s) State.ESPDist=s end)
    label(pg,"环境")
    toggle(pg,"全亮 Fullbright",false,function(s) State.Fullbright=s; if s then Lighting.Brightness=3;Lighting.ClockTime=14;Lighting.FogEnd=1e9;Lighting.GlobalShadows=false else Lighting.GlobalShadows=true end end)
end

--------------------------------------------------------------------
-- 🎯 玩家页
--------------------------------------------------------------------
do
    local pg=Pages["玩家"]
    label(pg,"传送到玩家")
    local list=new("Frame",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y})
    new("UIListLayout",{Parent=list,Padding=UDim.new(0,6)})
    local function refresh()
        for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _,p in ipairs(Players:GetPlayers()) do if p~=LP then
            local b=new("TextButton",{Parent=list,Size=UDim2.new(1,0,0,34),BackgroundColor3=T.card,Text="  ➜  "..p.Name,TextColor3=T.text,Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},{corner(8),stroke()})
            b.MouseButton1Click:Connect(function() local _,_,hrp=getChar(); local tc=p.Character and p.Character:FindFirstChild("HumanoidRootPart"); if hrp and tc then hrp.CFrame=tc.CFrame*CFrame.new(0,0,3) end end)
        end end
    end
    refresh(); button(pg,"🔄 刷新列表",refresh)
    Players.PlayerAdded:Connect(function() task.wait(0.5); refresh() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.5); refresh() end)
end

--------------------------------------------------------------------
-- ⚙️ 其他页
--------------------------------------------------------------------
do
    local pg=Pages["其他"]
    label(pg,"防护 & 工具")
    toggle(pg,"防倒地 Anti-Ragdoll",false,function(s) State.AntiRag=s end)
    toggle(pg,"防摔死 Anti-Void",false,function(s) State.AntiVoid=s end)
    toggle(pg,"防挂机踢出",true,function(s) State.AntiAFK=s end)
    button(pg,"💀 重生角色",function() local _,h=getChar(); if h then h.Health=0 end end)
    button(pg,"📍 复制坐标",function() local _,_,hrp=getChar(); if hrp and setclipboard then setclipboard(tostring(hrp.Position)) end end)
    label(pg,"关于")
    new("TextLabel",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,66),Font=Enum.Font.Gotham,TextSize=11,TextColor3=T.dim,TextWrapped=true,Text="APEX OMNI · 最强战场 AI 大脑\n右 Ctrl 开关面板 · 顶栏拖动\ngetgenv().__APEX_STATE 可脚本化控制"})
end

--==================================================================
-- VIM 真实输入
--==================================================================
local KEYNUM={[1]=Enum.KeyCode.One,[2]=Enum.KeyCode.Two,[3]=Enum.KeyCode.Three,[4]=Enum.KeyCode.Four,[5]=Enum.KeyCode.Five,[6]=Enum.KeyCode.Six,[7]=Enum.KeyCode.Seven,[8]=Enum.KeyCode.Eight}
local function keyDown(kc) pcall(function() VIM:SendKeyEvent(true,kc,false,game) end) end
local function keyUp(kc) pcall(function() VIM:SendKeyEvent(false,kc,false,game) end) end
local function tapKey(kc,hold) keyDown(kc); task.wait(hold or 0.04); keyUp(kc) end
local function safePoint()
    local vp=Cam.ViewportSize; local px,py=vp.X*0.5,vp.Y*0.12
    local mp,ms=Main.AbsolutePosition,Main.AbsoluteSize
    if px>mp.X-14 and px<mp.X+ms.X+14 and py>mp.Y-14 and py<mp.Y+ms.Y+14 then
        py=mp.Y-42; if py<14 then py=mp.Y+ms.Y+42 end; if py>vp.Y-14 then px=mp.X-42 end
    end
    return px,py
end
local function m1Click()
    local px,py=safePoint()
    pcall(function()
        VIM:SendMouseButtonEvent(px,py,0,true,game,0)
        VIM:SendMouseButtonEvent(px,py,0,false,game,0)
    end)
end
local function useSkill(slot) local kc=KEYNUM[slot]; if kc then tapKey(kc,0.05) end end

--==================================================================
-- 技能读取(从 Hotbar 动态识别装备的技能 + 角色定位)
--==================================================================
local function readSkills()
    local out={}
    local hb=LP.PlayerGui:FindFirstChild("Hotbar")
    hb=hb and hb:FindFirstChild("Backpack"); hb=hb and hb:FindFirstChild("Hotbar")
    if not hb then return out end
    for i=1,8 do
        local slot=hb:FindFirstChild(tostring(i))
        local base=slot and slot:FindFirstChild("Base")
        if slot and base and slot.Visible then
            local tn=base:FindFirstChild("ToolName")
            local reuse=base:FindFirstChild("Reuse")
            local name=(tn and tn.Text or ""):lower()
            out[i]={slot=i,name=name,ready=not (reuse and reuse.Visible)}
        end
    end
    return out
end
-- 按角色关键词识别技能用途(适配不同 moveset)
local function pickSkill(skills,keywords)
    for _,sk in pairs(skills) do
        for _,kw in ipairs(keywords) do
            if sk.name:find(kw) then return sk end
        end
    end
end

--==================================================================
-- 索敌 / 预判
--==================================================================
local function nearestEnemy()
    local _,_,hrp=getChar(); if not hrp then return end
    local best,bd,bhrp,bh=nil,State.FightRange,nil,nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and p.Character then
            local h=p.Character:FindFirstChildOfClass("Humanoid"); local t=p.Character:FindFirstChild("HumanoidRootPart")
            if h and t and h.Health>0 then local d=(t.Position-hrp.Position).Magnitude; if d<bd then best,bd,bhrp,bh=p.Character,d,t,h end end
        end
    end
    if not State.PlayersOnly then
        local live=Workspace:FindFirstChild("Live")
        if live then for _,m in ipairs(live:GetChildren()) do
            if m~=LP.Character and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
                local h=m:FindFirstChildOfClass("Humanoid"); local t=m:FindFirstChild("HumanoidRootPart")
                if h and t and h.Health>0 then local d=(t.Position-hrp.Position).Magnitude; if d<bd then best,bd,bhrp,bh=m,d,t,h end end
            end
        end end
    end
    return best,bd,bhrp,bh
end

--==================================================================
-- 🧠 AI 战斗大脑 —— 状态机
--   优先级: 保命(逃生) > 反应格挡/闪避 > 拆盾 > 大招 > 连招输出 > 接近 > 索敌
--==================================================================
task.spawn(function()
    local blockHeld=false
    local lastM1=0
    local lastSkill=0
    local parryUntil=0
    local dodgeUntil=0
    local enemyM1=setmetatable({},{__mode="k"})
    local enemySkill=setmetatable({},{__mode="k"})
    local skillRot=1

    local function setBlock(on)
        if on and not blockHeld then keyDown(Enum.KeyCode.F); blockHeld=true
        elseif (not on) and blockHeld then keyUp(Enum.KeyCode.F); blockHeld=false end
    end
    local function faceTo(hrp,thrp)
        hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(thrp.Position.X,hrp.Position.Y,thrp.Position.Z))
    end

    while ScreenGui.Parent do
        task.wait(0.03)
        local char,h,hrp=getChar()
        local manual = State.AutoCombo or State.AutoBlock
        local active = State.AIBrain or manual

        if not active or not(char and hrp and h and h.Health>0) then
            setBlock(false); HUD.state=State.AIBrain and "等待重生" or "待机"; HUD.action="—"; HUD.target="无"
        else
            local now=os.clock()
            local target,dist,thrp,th=nearestEnemy()
            local skills=readSkills()
            local myHP = h.Health/h.MaxHealth*100

            -- ── 预判信号:敌人出手 ──
            local incomingM1,incomingSkill=false,false
            if target and dist<=32 then
                local m1=target:GetAttribute("LastM1Fire")
                if m1 and enemyM1[target]~=m1 then enemyM1[target]=m1; parryUntil=now+0.42; incomingM1=true end
                local sk=target:GetAttribute("LastSkill")
                if sk and enemySkill[target]~=sk then enemySkill[target]=sk; dodgeUntil=now+0.55; incomingSkill=true end
            end
            local reactiveBlock = State.ReactiveParry and now<parryUntil
            local reactiveDodge = State.SkillDodge and now<dodgeUntil

            -- 面向
            if target and thrp and State.AutoFace then faceTo(hrp,thrp) end

            ----------------------------------------------------------------
            -- 决策(AI 大脑)
            ----------------------------------------------------------------
            if State.AIBrain then
                HUD.target = target and (Players:GetPlayerFromCharacter(target) and Players:GetPlayerFromCharacter(target).Name or target.Name) or "无"
                HUD.dist = math.floor(dist or 0)
                HUD.combo = char:GetAttribute("Combo") or 0
                HUD.threat = (target and dist<=16) and "高" or (target and dist<=40 and "中" or "低")

                if State.AutoEscape and myHP<=State.EscapeHP and target then
                    -- 逃生:拉开 + 格挡,残血时用挑空技能打断对方
                    HUD.state="🛟逃生"; HUD.action="拉开+格挡"
                    setBlock(true)
                    if State.AutoApproach then h:MoveTo(hrp.Position+(hrp.Position-thrp.Position).Unit*40) end
                    local up=State.UseSkills and pickSkill(skills,{"uppercut","launch","spin","kick"})
                    if up and up.ready and dist<=12 then setBlock(false); useSkill(up.slot); HUD.action="挑空打断" end

                elseif reactiveDodge and target then
                    -- 敌人放技能:优先规避(技能可能破防),拉侧身 + 格挡兜底
                    HUD.state="🌀闪避技能"; HUD.action="侧移规避"
                    setBlock(true)
                    local side=(thrp.Position-hrp.Position).Unit:Cross(Vector3.new(0,1,0))
                    h:MoveTo(hrp.Position+side*14)

                elseif reactiveBlock then
                    setBlock(true); HUD.state="⚡完美格挡"; HUD.action="Block"

                elseif target and thrp and dist<=State.ComboReach then
                    -- 输出窗口
                    setBlock(false)
                    if State.HitboxTP then
                        hrp.CFrame=CFrame.lookAt(thrp.Position-(thrp.Position-hrp.Position).Unit*2.5,Vector3.new(thrp.Position.X,hrp.Position.Y,thrp.Position.Z))
                    end
                    if th and th.Parent and target:GetAttribute("Blocking") and State.BlockBreak then
                        -- 对方格挡 → 破防技能(Shove/Grab/Kick)
                        local bb=State.UseSkills and pickSkill(skills,{"shove","grab","kick","throw","slam"})
                        if bb and bb.ready then useSkill(bb.slot); HUD.state="🔨拆盾"; HUD.action=bb.name
                        else m1Click(); HUD.state="🔨拆盾"; HUD.action="M1破防" end
                        lastSkill=now
                    else
                        HUD.state="⚔️连招输出"
                        local myCombo=char:GetAttribute("Combo") or 0
                        local ready = char:GetAttribute("M1Ready")
                        -- M1 主循环
                        if (ready==nil or ready==true) and not char:GetAttribute("Blocking") and now-lastM1>=0.30 then
                            m1Click(); lastM1=now; HUD.action="M1"
                        end
                        -- 连招点:combo 打满接技能(挑空→连击→破防 轮转)
                        if State.UseSkills and now-lastSkill>=0.9 and myCombo>=3 then
                            local seq={}
                            if State.AutoLauncher then seq[#seq+1]=pickSkill(skills,{"uppercut","launch","spin"}) end
                            seq[#seq+1]=pickSkill(skills,{"consecutive","barrage","combo","punches","rush"})
                            seq[#seq+1]=pickSkill(skills,{"shove","slam","kick","grab"})
                            -- 轮转找一个 ready 的
                            for off=0,#seq-1 do
                                local idx=((skillRot-1+off)%#seq)+1
                                local sk=seq[idx]
                                if sk and sk.ready then useSkill(sk.slot); HUD.action="技能:"..sk.name; lastSkill=now; skillRot=idx+1; break end
                            end
                        end
                    end

                    -- 大招
                    if State.AutoUlt and now-lastSkill>=1.5 then
                        local ult=pickSkill(skills,{"serious","ultimate","final","awaken"})
                        if ult and ult.ready then useSkill(ult.slot); HUD.action="💥"..ult.name; lastSkill=now end
                    end

                elseif target and thrp then
                    -- 接近
                    HUD.state="🏃接近"; HUD.action="靠近目标"
                    if State.AutoApproach then h:MoveTo(thrp.Position) end
                    setBlock(dist<=26 and true or false) -- 中距离举盾防偷袭
                else
                    HUD.state="🔍索敌"; HUD.action="—"; setBlock(false)
                end

            ----------------------------------------------------------------
            -- 手动模式(大脑关闭时)
            ----------------------------------------------------------------
            else
                if reactiveBlock then setBlock(true); HUD.state="⚡反应格挡"
                elseif State.AutoCombo and target and thrp and dist<=State.ComboReach then
                    setBlock(false)
                    local ready=char:GetAttribute("M1Ready")
                    if (ready==nil or ready==true) and not char:GetAttribute("Blocking") and now-lastM1>=0.30 then m1Click(); lastM1=now end
                    HUD.state="⚔️连招"
                elseif target and thrp then
                    if State.AutoApproach then h:MoveTo(thrp.Position) end
                    setBlock(State.AutoBlock); HUD.state=State.AutoApproach and "🏃接近" or "索敌"
                else setBlock(State.AutoBlock); HUD.state=State.AutoBlock and "🛡️待命" or "索敌" end
                HUD.target=target and target.Name or "无"; HUD.dist=math.floor(dist or 0); HUD.combo=char:GetAttribute("Combo") or 0
            end
        end
    end
    setBlock(false)
end)

--==================================================================
-- 通用循环:速度/穿墙/飞行/防护/无限跳
--==================================================================
local flyBV,flyBG
local function startFly() local _,h,hrp=getChar(); if not hrp then return end
    if flyBV then flyBV:Destroy() end; if flyBG then flyBG:Destroy() end
    flyBV=new("BodyVelocity",{Parent=hrp,MaxForce=Vector3.new(1,1,1)*9e9,Velocity=Vector3.zero,P=1250})
    flyBG=new("BodyGyro",{Parent=hrp,MaxTorque=Vector3.new(1,1,1)*9e9,P=9e4}); if h then h.PlatformStand=true end end
local function stopFly() if flyBV then flyBV:Destroy();flyBV=nil end if flyBG then flyBG:Destroy();flyBG=nil end local _,h=getChar(); if h then h.PlatformStand=false end end

bind("main",RunService.Heartbeat:Connect(function()
    local char,h,hrp=getChar(); if not char or not hrp then return end
    if State.SpeedLock and h and h.WalkSpeed~=State.WalkSpeed and not State.AIBrain then h.WalkSpeed=State.WalkSpeed end
    if State.Noclip then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end end
    if State.Fly then
        if not flyBV or flyBV.Parent~=hrp then startFly() end
        local dir=Vector3.zero; local look=Cam.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.new(0,1,0) end
        if flyBV then flyBV.Velocity=(dir.Magnitude>0 and dir.Unit or Vector3.zero)*State.FlySpeed end
        if flyBG then flyBG.CFrame=look end
    elseif flyBV then stopFly() end
    if State.AntiRag then if char:GetAttribute("Ragdoll") then pcall(function() char:SetAttribute("Ragdoll",false) end) end local r=char:FindFirstChild("Ragdoll"); if r then pcall(function() r:Destroy() end) end if h and h.Sit then h.Sit=false end end
    if State.AntiVoid and hrp.Position.Y<-50 then hrp.CFrame=CFrame.new(110,445,-11); hrp.AssemblyLinearVelocity=Vector3.zero end
end))

bind("hud",RunService.RenderStepped:Connect(function()
    if BrainHUD then
        local col = HUD.state:find("逃生") and T.danger or HUD.state:find("格挡") and T.on or HUD.state:find("闪避") and T.warn or HUD.state:find("连招") and T.accentB or T.text
        BrainHUD.Text=string.format("● 状态: %s\n◎ 目标: %s  [%dm]  威胁:%s\n◎ 连招: %d\n➤ 动作: %s",HUD.state,HUD.target,HUD.dist,HUD.threat,HUD.combo,HUD.action)
        BrainHUD.TextColor3=col
    end
    if State.ESP then
        local _,_,my=getChar()
        for plr,f in pairs(ESPStore) do
            if plr.Parent and f.tl then
                local ch=plr.Character; local t=ch and ch:FindFirstChild("HumanoidRootPart")
                if t and my and State.ESPDist then f.tl.Text=plr.Name.."  ["..math.floor((t.Position-my.Position).Magnitude).."m]" else f.tl.Text=plr.Name end
            end
        end
    end
end))

bind("infjump",UserInputService.JumpRequest:Connect(function() if State.InfJump then local _,h=getChar(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end))
bind("espAdd",Players.PlayerAdded:Connect(function(p) if State.ESP then task.wait(0.5); makeESP(p) end end))
bind("espRem",Players.PlayerRemoving:Connect(function(p) if ESPStore[p] then ESPStore[p]:Destroy(); ESPStore[p]=nil end end))
bind("charAdd",LP.CharacterAdded:Connect(function() task.wait(1); if State.ESP then clearESP(); for _,p in ipairs(Players:GetPlayers()) do makeESP(p) end end end))
bind("afk",LP.Idled:Connect(function() if State.AntiAFK then pcall(function() local vu=game:GetService("VirtualUser"); vu:CaptureController(); vu:ClickButton2(Vector2.new()) end) end end))

--==================================================================
-- 霓虹描边 + 底部辉光动画 · 快捷键 · 开场
--==================================================================
bind("neon",RunService.RenderStepped:Connect(function()
    local t=tick()*0.14; local hue=t%1
    neonGrad.Color=ColorSequence.new(Color3.fromHSV(hue,0.7,1),Color3.fromHSV((hue+0.28)%1,0.7,1))
    neonGrad.Rotation=(t*100)%360
    -- 底部辉光随大脑状态呼吸
    local glowCol = HUD.state:find("逃生") and T.danger or (HUD.state:find("连招") or HUD.state:find("拆盾")) and T.accentB or T.accentA
    underGlow.BackgroundColor3=glowCol
    underGlow.BackgroundTransparency=0.15+0.15*math.sin(tick()*3)
end))
bind("togglekey",UserInputService.InputBegan:Connect(function(io,gpe) if gpe then return end if io.KeyCode==Enum.KeyCode.RightControl then Main.Visible=not Main.Visible end end))

selectTab("AI 大脑")
Main.Size=UDim2.fromOffset(0,0); Main.BackgroundTransparency=1
TweenService:Create(Main,TweenInfo.new(0.4,Enum.EasingStyle.Back),{Size=UDim2.fromOffset(600,410),BackgroundTransparency=0}):Play()

task.spawn(function()
    local n=new("Frame",{Parent=ScreenGui,Size=UDim2.fromOffset(280,56),Position=UDim2.new(1,20,1,-84),BackgroundColor3=T.bg2},{corner(12),stroke(T.accentA,1.5)})
    new("TextLabel",{Parent=n,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-20,1,0),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text="🧠 APEX OMNI 已加载\nAI 战斗大脑就绪 · 右Ctrl 开关"})
    TweenService:Create(n,TweenInfo.new(0.5,Enum.EasingStyle.Quint),{Position=UDim2.new(1,-300,1,-84)}):Play()
    task.wait(4.5); TweenService:Create(n,TweenInfo.new(0.5),{Position=UDim2.new(1,20,1,-84)}):Play(); task.wait(0.6); n:Destroy()
end)

print("[APEX OMNI] AI 大脑已加载 ✓")
