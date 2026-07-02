--[[
  █████╗ ██████╗ ███████╗██╗  ██╗   ██████╗ ███╗   ███╗███╗   ██╗██╗
 ██╔══██╗██╔══██╗██╔════╝╚██╗██╔╝  ██╔═══██╗████╗ ████║████╗  ██║██║
 ███████║██████╔╝█████╗   ╚███╔╝   ██║   ██║██╔████╔██║██╔██╗ ██║██║
 ██╔══██║██╔═══╝ ██╔══╝   ██╔██╗   ██║   ██║██║╚██╔╝██║██║╚██╗██║██║
 ██║  ██║██║     ███████╗██╔╝ ██╗  ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║
 ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝
  最强战场 · APEX OMNI v2 —— 行为自适应 AI 战斗大脑
  · 敌人角色识别 + 出招行为分类(莽夫/法师/抓手/乌龟)→ 动态战术
  · Q 抓取穿盾(专克挂机格挡脚本) · 帧级反应格挡/闪避 · 1v多风筝
  · 自适应连招(读自身技能自动编排) · 威胁排序 · 预判走位 · 配置记忆
]]

if getgenv and getgenv().__APEX then pcall(function() getgenv().__APEX:Destroy() end) end

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local Workspace=game:GetService("Workspace")
local VIM=game:GetService("VirtualInputManager")
local LP=Players.LocalPlayer
local Cam=Workspace.CurrentCamera
local Mouse=LP:GetMouse()

--==================================================================
-- 配置(可持久化)
--==================================================================
local State={
    -- AI 大脑
    AIBrain=false, UseSkills=true, AutoLauncher=true, QGrab=true, SkillDodge=true,
    ReactiveParry=true, AutoUlt=true, AutoEscape=true, KiteMultiple=false, PredictAim=true,
    ExecutePriority=true, DashClose=true,
    -- 激进 / 全场
    TPChase=true, TPBehind=false, KillAura=false, KillAuraRange=65, Reach=false, ReachSize=9,
    EscapeHP=20, PredictLead=0.12, Aggression=9,
    -- 基础
    AutoCombo=false, AutoBlock=false, HitboxTP=false, AutoApproach=true, AutoFace=true,
    PlayersOnly=true, FightRange=90, ComboReach=14,
    -- 移动
    Fly=false, FlySpeed=60, Noclip=false, InfJump=false, WalkSpeed=16, JumpPower=45, SpeedLock=false,
    -- 视觉
    ESP=false, ESPDist=true, ESPChar=true, Fullbright=false,
    AntiRag=false, AntiVoid=false, AntiAFK=true,
}
local CFG_FILE="apex_omni_config.json"
local function saveCfg()
    if not writefile then return end
    pcall(function()
        local t={}; for k,v in pairs(State) do if type(v)~="function" then t[k]=v end end
        writefile(CFG_FILE, game:GetService("HttpService"):JSONEncode(t))
    end)
end
local function loadCfg()
    if not (readfile and isfile and isfile(CFG_FILE)) then return end
    pcall(function()
        local t=game:GetService("HttpService"):JSONDecode(readfile(CFG_FILE))
        for k,v in pairs(t) do if State[k]~=nil then State[k]=v end end
    end)
end
loadCfg()

-- 实时决策 HUD
local HUD={state="待机",target="无",dist=0,combo=0,action="—",archetype="—",enemyChar="—",threat="低",hp=100}

local Conn={}
local function bind(n,c) Conn[n]=c end
local function getChar() local c=LP.Character; if not c then return end; return c,c:FindFirstChildOfClass("Humanoid"),c:FindFirstChild("HumanoidRootPart") end

--==================================================================
-- 主题 + 组件工厂
--==================================================================
local T={bg=Color3.fromRGB(13,13,19),bg2=Color3.fromRGB(21,21,31),card=Color3.fromRGB(29,29,43),
 stroke=Color3.fromRGB(54,54,80),text=Color3.fromRGB(237,237,247),dim=Color3.fromRGB(150,150,172),
 accentA=Color3.fromRGB(140,90,255),accentB=Color3.fromRGB(0,212,255),on=Color3.fromRGB(90,235,160),
 off=Color3.fromRGB(62,62,88),warn=Color3.fromRGB(255,172,80),danger=Color3.fromRGB(255,84,110)}
local function new(cls,p,k) local o=Instance.new(cls); for a,b in pairs(p or {}) do o[a]=b end; for _,c in ipairs(k or {}) do c.Parent=o end; return o end
local function corner(r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8)}) end
local function stroke(c,t) return new("UIStroke",{Color=c or T.stroke,Thickness=t or 1,Transparency=0.15}) end
local function pad(p) return new("UIPadding",{PaddingTop=UDim.new(0,p),PaddingBottom=UDim.new(0,p),PaddingLeft=UDim.new(0,p),PaddingRight=UDim.new(0,p)}) end
local function grad(rot,a,b) return new("UIGradient",{Color=ColorSequence.new(a or T.accentA,b or T.accentB),Rotation=rot or 0}) end

local DESIGN_MAIN_SIZE=Vector2.new(620,430)
local MINIMIZED_MAIN_SIZE=Vector2.new(620,48)
local MIN_UI_SCALE=0.58
local MOBILE_VIEWPORT_X=820
local function getViewportSize()
    local camera=Workspace.CurrentCamera
    if camera then return camera.ViewportSize end
    return Vector2.new(1280,720)
end
local function isCompactViewport()
    local vp=getViewportSize()
    return UserInputService.TouchEnabled or vp.X<=MOBILE_VIEWPORT_X
end
local function getTargetScale(size)
    local vp=getViewportSize()
    local marginX=isCompactViewport() and 24 or 140
    local marginY=isCompactViewport() and 32 or 140
    local availableX=math.max(280,vp.X-marginX)
    local availableY=math.max(220,vp.Y-marginY)
    return math.clamp(math.min(availableX/size.X,availableY/size.Y,1),MIN_UI_SCALE,1)
end

local ScreenGui=new("ScreenGui",{Name="APEX_V2",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true})
pcall(function() ScreenGui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent=LP:WaitForChild("PlayerGui") end
if getgenv then getgenv().__APEX=ScreenGui; getgenv().__APEX_STATE=State end

local Main=new("Frame",{Name="Main",Parent=ScreenGui,AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(DESIGN_MAIN_SIZE.X,DESIGN_MAIN_SIZE.Y),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=T.bg,BorderSizePixel=0},{corner(16)})
local MainScale=new("UIScale",{Parent=Main,Scale=1})
-- 柔和投影(向下,层次感,不是彩色光圈)
new("ImageLabel",{Parent=Main,BackgroundTransparency=1,ZIndex=0,Image="rbxassetid://6015897843",ImageColor3=Color3.new(0,0,0),ImageTransparency=0.35,Size=UDim2.new(1,48,1,54),Position=UDim2.new(0,-24,0,-18),ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(49,49,450,450)})
local underGlow=new("Frame",{Parent=Main,BackgroundColor3=T.accentA,BorderSizePixel=0,ZIndex=0,Size=UDim2.new(0.72,0,0,4),Position=UDim2.new(0.14,0,1,-2)},{corner(4),grad(0,T.accentA,T.accentB)})
local neon=new("UIStroke",{Parent=Main,Thickness=1.6,Transparency=0,Color=Color3.new(1,1,1)})
local neonGrad=grad(0); neonGrad.Parent=neon
new("Frame",{Parent=Main,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.9,BorderSizePixel=0,Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,0,1)})

local Top=new("Frame",{Name="Top",Parent=Main,Size=UDim2.new(1,0,0,48),BackgroundColor3=T.bg2,BorderSizePixel=0},{corner(16)})
new("Frame",{Parent=Top,Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,1,-16),BackgroundColor3=T.bg2,BorderSizePixel=0})
local Logo=new("Frame",{Parent=Top,Size=UDim2.fromOffset(28,28),Position=UDim2.new(0,16,0.5,-14),BackgroundColor3=Color3.new(1,1,1)},{corner(8),grad(45)})
new("TextLabel",{Parent=Logo,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.GothamBlack,Text="A",TextColor3=T.bg,TextSize=16})
local Title=new("TextLabel",{Parent=Top,BackgroundTransparency=1,Position=UDim2.new(0,56,0,5),Size=UDim2.new(1,-190,0,20),Font=Enum.Font.GothamBlack,TextSize=19,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text="APEX OMNI v2"})
new("TextLabel",{Parent=Top,BackgroundTransparency=1,Position=UDim2.new(0,56,0,25),Size=UDim2.new(1,-190,0,15),Font=Enum.Font.GothamMedium,TextSize=11,TextColor3=T.dim,TextXAlignment=Enum.TextXAlignment.Left,Text="行为自适应 AI · 最强战场"})
do local g=grad(0); g.Parent=Title; task.spawn(function() while Title.Parent do TweenService:Create(g,TweenInfo.new(3,Enum.EasingStyle.Linear),{Offset=Vector2.new(1,0)}):Play(); task.wait(3); g.Offset=Vector2.new(-1,0) end end) end
local function topBtn(txt,x,col) return new("TextButton",{Parent=Top,Size=UDim2.fromOffset(28,28),Position=UDim2.new(1,x,0.5,-14),BackgroundColor3=T.card,Text=txt,TextColor3=col or T.text,Font=Enum.Font.GothamBold,TextSize=16},{corner(8),stroke()}) end
local MinBtn=topBtn("—",-84,T.dim); local CloseBtn=topBtn("✕",-44,T.danger)

local Body=new("Frame",{Parent=Main,BackgroundTransparency=1,Position=UDim2.new(0,0,0,48),Size=UDim2.new(1,0,1,-48)})
local Side=new("Frame",{Parent=Body,BackgroundColor3=T.bg2,BorderSizePixel=0,Size=UDim2.new(0,146,1,0)})
new("UIListLayout",{Parent=Side,Padding=UDim.new(0,5),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder})
new("UIPadding",{Parent=Side,PaddingTop=UDim.new(0,10)})
local Content=new("Frame",{Parent=Body,BackgroundTransparency=1,Position=UDim2.new(0,146,0,0),Size=UDim2.new(1,-146,1,0)})
local Pages,Tabs={},{}
local function makePage(n) local sc=new("ScrollingFrame",{Parent=Content,Visible=false,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=T.accentA,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y},{pad(14)}); new("UIListLayout",{Parent=sc,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder}); Pages[n]=sc; return sc end
local function selectTab(n) for a,p in pairs(Pages) do p.Visible=(a==n) end for a,b in pairs(Tabs) do TweenService:Create(b,TweenInfo.new(0.2),{BackgroundColor3=(a==n) and T.card or T.bg2,TextColor3=(a==n) and T.text or T.dim}):Play(); local s=b:FindFirstChildOfClass("UIStroke"); if s then TweenService:Create(s,TweenInfo.new(0.2),{Transparency=(a==n) and 0 or 1}):Play() end end end
local function makeTab(n,ic) local b=new("TextButton",{Parent=Side,Size=UDim2.new(1,-14,0,34),BackgroundColor3=T.bg2,Text="  "..ic.."  "..n,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.dim,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false},{corner(9),stroke(T.accentA,1)}); b:FindFirstChildOfClass("UIStroke").Transparency=1; Tabs[n]=b; b.MouseButton1Click:Connect(function() selectTab(n) end); makePage(n); return b end

local function label(p,t) return new("TextLabel",{Parent=p,BackgroundTransparency=1,Size=UDim2.new(1,0,0,18),Font=Enum.Font.GothamBold,TextSize=11,TextColor3=T.accentB,TextXAlignment=Enum.TextXAlignment.Left,Text="▎ "..t}) end
local function toggle(p,txt,key,cb)
    local def=State[key]
    local row=new("Frame",{Parent=p,Size=UDim2.new(1,0,0,40),BackgroundColor3=T.card,BorderSizePixel=0},{corner(10),stroke()})
    new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-70,1,0),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=txt})
    local knob=new("Frame",{Parent=row,Size=UDim2.fromOffset(44,22),Position=UDim2.new(1,-56,0.5,-11),BackgroundColor3=def and T.on or T.off},{corner(11)})
    local dot=new("Frame",{Parent=knob,Size=UDim2.fromOffset(16,16),Position=def and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),BackgroundColor3=Color3.new(1,1,1)},{corner(8)})
    local st=def or false
    new("TextButton",{Parent=row,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Text=""}).MouseButton1Click:Connect(function()
        st=not st; if key then State[key]=st end
        TweenService:Create(knob,TweenInfo.new(0.18),{BackgroundColor3=st and T.on or T.off}):Play()
        TweenService:Create(dot,TweenInfo.new(0.18,Enum.EasingStyle.Back),{Position=st and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        if cb then pcall(cb,st) end; saveCfg()
    end)
    return row
end
local function slider(p,txt,mn,mx,key,cb)
    local def=State[key] or mn
    local row=new("Frame",{Parent=p,Size=UDim2.new(1,0,0,52),BackgroundColor3=T.card,BorderSizePixel=0},{corner(10),stroke()})
    new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(0,14,0,6),Size=UDim2.new(1,-28,0,18),Font=Enum.Font.GothamMedium,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=txt})
    local val=new("TextLabel",{Parent=row,BackgroundTransparency=1,Position=UDim2.new(1,-60,0,6),Size=UDim2.new(0,46,0,18),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.accentB,TextXAlignment=Enum.TextXAlignment.Right,Text=tostring(def)})
    local bar=new("Frame",{Parent=row,Position=UDim2.new(0,14,1,-16),Size=UDim2.new(1,-28,0,6),BackgroundColor3=T.bg},{corner(3)})
    local fill=new("Frame",{Parent=bar,BackgroundColor3=Color3.new(1,1,1),Size=UDim2.new((def-mn)/(mx-mn),0,1,0)},{corner(3),grad(0)})
    local drag=false
    local dragInput
    local function set(x) local rel=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1); fill.Size=UDim2.new(rel,0,1,0); local v=math.floor((mn+(mx-mn)*rel)*100+0.5)/100; val.Text=tostring(v); if key then State[key]=v end; if cb then pcall(cb,v) end end
    local hitbox=new("TextButton",{Parent=bar,BackgroundTransparency=1,Size=UDim2.new(1,0,3,0),Position=UDim2.new(0,0,-1,0),Text=""})
    hitbox.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true
            dragInput=i
            set(i.Position.X)
        end
    end)
    hitbox.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            dragInput=i
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if drag and (i==dragInput or i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then
            drag=false
            dragInput=nil
            saveCfg()
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i==dragInput or i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            set(i.Position.X)
        end
    end)
    return row
end
local function button(p,txt,cb) local b=new("TextButton",{Parent=p,Size=UDim2.new(1,0,0,38),BackgroundColor3=T.card,Text=txt,TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=13,AutoButtonColor=false},{corner(10),stroke(T.accentA,1)}); b:FindFirstChildOfClass("UIStroke").Transparency=0.4; b.MouseButton1Click:Connect(function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=T.accentA}):Play(); task.delay(0.12,function() TweenService:Create(b,TweenInfo.new(0.2),{BackgroundColor3=T.card}):Play() end); pcall(cb) end); return b end

-- 拖动/最小化/关闭
local function getMainSizeUDim2()
    local size=mind and MINIMIZED_MAIN_SIZE or DESIGN_MAIN_SIZE
    return UDim2.fromOffset(size.X,size.Y)
end
local function applyResponsiveLayout()
    MainScale.Scale=getTargetScale(mind and MINIMIZED_MAIN_SIZE or DESIGN_MAIN_SIZE)
end
do local dr,ds,sp,dragInput; Top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dr=true; dragInput=i; ds=i.Position; sp=Main.Position end end)
   Top.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end end)
   UserInputService.InputChanged:Connect(function(i) if dr and i==dragInput then local d=i.Position-ds; Main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
   UserInputService.InputEnded:Connect(function(i) if dr and (i==dragInput or i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dr=false; dragInput=nil end end) end
local mind=false
MinBtn.MouseButton1Click:Connect(function() mind=not mind; TweenService:Create(Main,TweenInfo.new(0.25,Enum.EasingStyle.Quart),{Size=getMainSizeUDim2()}):Play(); Body.Visible=not mind; underGlow.Visible=not mind; applyResponsiveLayout() end)
CloseBtn.MouseButton1Click:Connect(function() for _,c in pairs(Conn) do pcall(function() c:Disconnect() end) end; TweenService:Create(Main,TweenInfo.new(0.25),{Size=UDim2.fromOffset(0,0),Position=UDim2.new(0.5,0,0.5,0)}):Play(); task.wait(0.26); ScreenGui:Destroy(); if getgenv then getgenv().__APEX=nil end end)

--==================================================================
makeTab("AI 大脑","🧠"); makeTab("战斗","⚔️"); makeTab("连招/角色","🥋"); makeTab("移动","🏃"); makeTab("视觉","👁️"); makeTab("玩家","🎯"); makeTab("其他","⚙️")

-- 🧠 AI 大脑页
local BrainHUD
do local pg=Pages["AI 大脑"]
    label(pg,"AI 决策实况")
    local card=new("Frame",{Parent=pg,Size=UDim2.new(1,0,0,118),BackgroundColor3=T.bg2,BorderSizePixel=0},{corner(12),stroke(T.accentB,1.2)})
    new("UIGradient",{Parent=card,Rotation=30,Color=ColorSequence.new(T.bg2,T.card)})
    BrainHUD=new("TextLabel",{Parent=card,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-24,1,0),Font=Enum.Font.Code,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Text="● 大脑离线"})
    label(pg,"主控")
    toggle(pg,"🧠 启动 AI 战斗大脑 (全自动接管)","AIBrain")
    label(pg,"核心能力")
    toggle(pg,"⚡ 用技能连招","UseSkills")
    toggle(pg,"🚀 挑空接浮空连","AutoLauncher")
    toggle(pg,"🤼 Q 抓取穿盾 (克格挡脚本)","QGrab")
    toggle(pg,"🌀 预判闪避敌方技能","SkillDodge")
    toggle(pg,"⚡ 帧级反应格挡","ReactiveParry")
    toggle(pg,"💥 自动大招","AutoUlt")
    toggle(pg,"🛟 残血自动逃生","AutoEscape")
    toggle(pg,"🔮 预判走位 (打提前量)","PredictAim")
    toggle(pg,"☠️ 优先秒残血目标","ExecutePriority")
    toggle(pg,"💨 Q 冲刺接近","DashClose")
    label(pg,"⚔️ 激进 / 全场 (核心)")
    toggle(pg,"🔒 TP 锁身追击 (贴脸不放·修进攻性)","TPChase")
    toggle(pg,"☠️ Kill Aura (瞬移轮打全场·有风险)","KillAura")
    slider(pg,"KillAura 范围",20,120,"KillAuraRange")
    toggle(pg,"🎯 1v多 风筝 (保守·默认关)","KiteMultiple")
    slider(pg,"逃生血量%",5,60,"EscapeHP")
    slider(pg,"进攻性 (1保守-10激进)",1,10,"Aggression")
    slider(pg,"索敌范围",30,200,"FightRange")
end

-- ⚔️ 战斗页
do local pg=Pages["战斗"]
    label(pg,"手动开关 (大脑关闭时生效)")
    toggle(pg,"⚔️ 自动连招 (纯M1)","AutoCombo")
    toggle(pg,"🛡️ 自动格挡","AutoBlock")
    label(pg,"通用战术")
    toggle(pg,"📌 命中盒锁定 (瞬移贴脸)","HitboxTP")
    toggle(pg,"🏃 自动接近","AutoApproach")
    toggle(pg,"🎯 自动面向","AutoFace")
    toggle(pg,"👤 只锁真人","PlayersOnly")
    slider(pg,"连招距离",8,30,"ComboReach")
    slider(pg,"预判提前量(秒)",0,0.4,"PredictLead")
    label(pg,"实验性 (需真人局验证)")
    toggle(pg,"📡 命中盒扩大 Reach","Reach")
    slider(pg,"命中盒尺寸",4,25,"ReachSize")
    button(pg,"🧍 木桩传面前 (测试)",function() local d=Workspace:FindFirstChild("Live") and Workspace.Live:FindFirstChild("Weakest Dummy"); local _,_,h=getChar(); local dh=d and d:FindFirstChild("HumanoidRootPart"); if dh and h then dh.CFrame=h.CFrame*CFrame.new(0,0,-4) end end)
end

-- 🥋 连招/角色页(实况)
local ComboHUD
do local pg=Pages["连招/角色"]
    label(pg,"我方技能识别 & 敌方情报")
    local card=new("Frame",{Parent=pg,Size=UDim2.new(1,0,0,150),BackgroundColor3=T.bg2,BorderSizePixel=0},{corner(12),stroke(T.accentA,1.2)})
    ComboHUD=new("TextLabel",{Parent=card,BackgroundTransparency=1,Position=UDim2.new(0,14,0,10),Size=UDim2.new(1,-24,1,-20),Font=Enum.Font.Code,TextSize=12,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text="扫描中..."})
    new("TextLabel",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,70),Font=Enum.Font.Gotham,TextSize=11,TextColor3=T.dim,TextWrapped=true,Text="大脑会实时读取你当前角色的技能并自动分类(挑空/连击/破防/远程/位移),按最优顺序编排连招 —— 换任何角色/自定义 moveset 都自动适配。敌方角色与打法(莽夫/法师/抓手/乌龟)由行为实时判定。"})
end

-- 🏃 移动页
do local pg=Pages["移动"]
    label(pg,"速度 & 跳跃")
    slider(pg,"行走速度",16,250,"WalkSpeed",function(v) local _,h=getChar(); if h then h.WalkSpeed=v end end)
    slider(pg,"跳跃力",45,350,"JumpPower",function(v) local _,h=getChar(); if h then h.UseJumpPower=true; h.JumpPower=v end end)
    toggle(pg,"锁定速度(防重置)","SpeedLock")
    toggle(pg,"无限跳跃","InfJump")
    label(pg,"飞行 & 穿墙")
    toggle(pg,"飞行 (Space/Shift升降)","Fly")
    slider(pg,"飞行速度",20,300,"FlySpeed")
    toggle(pg,"穿墙 Noclip","Noclip")
end

-- 👁️ 视觉页
local ESPStore={}
local function clearESP() for _,f in pairs(ESPStore) do pcall(function() f:Destroy() end) end table.clear(ESPStore) end
local function makeESP(plr)
    if plr==LP or ESPStore[plr] then return end
    local f=new("Folder",{})
    local hl=new("Highlight",{FillColor=T.accentA,OutlineColor=T.accentB,FillTransparency=0.55,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,Parent=f})
    local bb=new("BillboardGui",{Size=UDim2.fromOffset(180,34),StudsOffset=Vector3.new(0,3.4,0),AlwaysOnTop=true,Parent=f})
    local tl=new("TextLabel",{Parent=bb,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.text,TextStrokeTransparency=0,Text=plr.Name})
    local function attach() local ch=plr.Character; if ch then hl.Parent=ch; bb.Adornee=ch:FindFirstChild("HumanoidRootPart") end end
    attach(); f.tl=tl; ESPStore[plr]=f
    bind("esp_"..plr.Name,plr.CharacterAdded:Connect(function() task.wait(0.4); attach() end))
end
do local pg=Pages["视觉"]
    label(pg,"透视 ESP")
    toggle(pg,"启用 ESP (高亮+名字)","ESP",function(s) if s then for _,p in ipairs(Players:GetPlayers()) do makeESP(p) end else clearESP() end end)
    toggle(pg,"显示距离","ESPDist")
    toggle(pg,"显示角色+打法","ESPChar")
    label(pg,"环境")
    toggle(pg,"全亮 Fullbright","Fullbright",function(s) if s then Lighting.Brightness=3;Lighting.ClockTime=14;Lighting.FogEnd=1e9;Lighting.GlobalShadows=false else Lighting.GlobalShadows=true end end)
end

-- 🎯 玩家页
do local pg=Pages["玩家"]
    label(pg,"传送到玩家")
    local list=new("Frame",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y}); new("UIListLayout",{Parent=list,Padding=UDim.new(0,6)})
    local function refresh() for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _,p in ipairs(Players:GetPlayers()) do if p~=LP then local b=new("TextButton",{Parent=list,Size=UDim2.new(1,0,0,34),BackgroundColor3=T.card,Text="  ➜  "..p.Name,TextColor3=T.text,Font=Enum.Font.GothamMedium,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left},{corner(8),stroke()})
            b.MouseButton1Click:Connect(function() local _,_,h=getChar(); local tc=p.Character and p.Character:FindFirstChild("HumanoidRootPart"); if h and tc then h.CFrame=tc.CFrame*CFrame.new(0,0,3) end end) end end end
    refresh(); button(pg,"🔄 刷新列表",refresh)
    Players.PlayerAdded:Connect(function() task.wait(0.5); refresh() end); Players.PlayerRemoving:Connect(function() task.wait(0.5); refresh() end)
end

-- ⚙️ 其他页
do local pg=Pages["其他"]
    label(pg,"防护 & 工具")
    toggle(pg,"防倒地 Anti-Ragdoll","AntiRag")
    toggle(pg,"防摔死 Anti-Void","AntiVoid")
    toggle(pg,"防挂机踢出","AntiAFK")
    button(pg,"💀 重生",function() local _,h=getChar(); if h then h.Health=0 end end)
    button(pg,"📍 复制坐标",function() local _,_,h=getChar(); if h and setclipboard then setclipboard(tostring(h.Position)) end end)
    button(pg,"💾 保存配置",function() saveCfg() end)
    label(pg,"关于")
    new("TextLabel",{Parent=pg,BackgroundTransparency=1,Size=UDim2.new(1,0,0,66),Font=Enum.Font.Gotham,TextSize=11,TextColor3=T.dim,TextWrapped=true,Text="APEX OMNI v2 · 行为自适应 AI\n右Ctrl 开关面板 · 配置自动记忆\ngetgenv().__APEX_STATE 可脚本化"})
end

--==================================================================
-- VIM 真实输入
--==================================================================
local KEYNUM={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,Enum.KeyCode.Seven,Enum.KeyCode.Eight}
local function kd(kc) pcall(function() VIM:SendKeyEvent(true,kc,false,game) end) end
local function ku(kc) pcall(function() VIM:SendKeyEvent(false,kc,false,game) end) end
local function tap(kc,h) kd(kc); task.wait(h or 0.045); ku(kc) end
local function safePoint() local vp=Cam.ViewportSize; local px,py=vp.X*0.5,vp.Y*0.12; local mp,ms=Main.AbsolutePosition,Main.AbsoluteSize
    if px>mp.X-14 and px<mp.X+ms.X+14 and py>mp.Y-14 and py<mp.Y+ms.Y+14 then py=mp.Y-42; if py<14 then py=mp.Y+ms.Y+42 end; if py>vp.Y-14 then px=mp.X-42 end end
    return px,py end
local function m1() local px,py=safePoint(); pcall(function() VIM:SendMouseButtonEvent(px,py,0,true,game,0); VIM:SendMouseButtonEvent(px,py,0,false,game,0) end) end
local function useSkill(slot) local kc=KEYNUM[slot]; if kc then tap(kc,0.05) end end
local function useQ() tap(Enum.KeyCode.Q,0.05) end

--==================================================================
-- 技能识别(读自身 Hotbar + 角色分类)
--==================================================================
local ROLE_KW={
    launcher={"uppercut","launch","rising","knee","spin","air","juggle","lift"},
    combo={"consecutive","barrage","combo","punches","rush","flurry","storm","rapid","fury"},
    blockbreak={"shove","grab","throw","slam","kick","headbutt","push","spike","pummel"},
    ranged={"beam","blast","wave","laser","ki","fireball","projectile","gun","shot","cannon","bomb"},
    heal={"heal","regen","restore","recover"},
    ult={"serious","ultimate","final","awaken","mode","limiter","transform"},
}
local function classify(name) name=name:lower()
    for role,kws in pairs(ROLE_KW) do for _,kw in ipairs(kws) do if name:find(kw) then return role end end end
    return "combo"
end
local function readSkills()
    local out={}
    local hb=LP.PlayerGui:FindFirstChild("Hotbar"); hb=hb and hb:FindFirstChild("Backpack"); hb=hb and hb:FindFirstChild("Hotbar")
    if not hb then return out end
    for i=1,8 do local s=hb:FindFirstChild(tostring(i)); local b=s and s:FindFirstChild("Base")
        if s and b and s.Visible then local tn=b:FindFirstChild("ToolName"); local reuse=b:FindFirstChild("Reuse")
            local nm=(tn and tn.Text or ""); out[#out+1]={slot=i,name=nm,role=classify(nm),ready=not(reuse and reuse.Visible)} end end
    return out
end
local function pickRole(skills,role) for _,s in ipairs(skills) do if s.role==role then return s end end end

--==================================================================
-- 敌人行为分类(莽夫/法师/抓手/乌龟)—— 通用,克任何角色/脚本
--==================================================================
local ENEMY=setmetatable({},{__mode="k"})  -- 每敌人行为统计
local function track(enemy)
    local rec=ENEMY[enemy]; if not rec then rec={m1=0,skill=0,block=0,dash=0,lastM1=0,lastSkill=0,lastDash=0,samples=0}; ENEMY[enemy]=rec end
    local m1t=enemy:GetAttribute("LastM1Fire"); local skt=enemy:GetAttribute("LastSkill"); local dst=enemy:GetAttribute("JustForwardDashed")
    if m1t and rec.lastM1~=m1t then rec.lastM1=m1t; rec.m1=rec.m1+1 end
    if skt and rec.lastSkill~=skt then rec.lastSkill=skt; rec.skill=rec.skill+1 end
    if dst and rec.lastDash~=dst then rec.lastDash=dst; rec.dash=rec.dash+1 end
    if enemy:GetAttribute("Blocking") then rec.block=rec.block+1 end
    rec.samples=rec.samples+1
    return rec
end
local function archetype(enemy,rec)
    local blockRate=rec.samples>0 and rec.block/rec.samples or 0
    if blockRate>0.4 then return "乌龟" end
    if rec.dash>=3 and rec.dash>rec.m1 then return "抓手" end
    if rec.skill>rec.m1*1.3 and rec.skill>=3 then return "法师" end
    if rec.m1>=3 then return "莽夫" end
    return "未知"
end

--==================================================================
-- 索敌 / 威胁排序 / 预判
--==================================================================
local function candidates()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then
        local h=p.Character:FindFirstChildOfClass("Humanoid"); local t=p.Character:FindFirstChild("HumanoidRootPart")
        if h and t and h.Health>0 then list[#list+1]={char=p.Character,h=h,t=t,name=p.Name,isPlayer=true} end end end
    if not State.PlayersOnly then local live=Workspace:FindFirstChild("Live")
        if live then for _,m in ipairs(live:GetChildren()) do if m~=LP.Character and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then
            local h=m:FindFirstChildOfClass("Humanoid"); local t=m:FindFirstChild("HumanoidRootPart")
            if h and t and h.Health>0 then list[#list+1]={char=m,h=h,t=t,name=m.Name,isPlayer=false} end end end end end
    return list
end
local function pickTarget(hrp)
    local best,bestScore,nearCount=nil,-1e9,0
    for _,c in ipairs(candidates()) do
        local d=(c.t.Position-hrp.Position).Magnitude
        if d<=State.FightRange then
            if d<=18 then nearCount=nearCount+1 end
            local score=1000-d
            -- 正在攻击我 → 提高威胁
            local m1t=c.char:GetAttribute("LastM1Fire")
            if m1t and os.clock()%1 then end
            -- 执行:残血目标优先
            if State.ExecutePriority then local hpr=c.h.Health/c.h.MaxHealth; if hpr<0.35 then score=score+400*(1-hpr) end end
            if score>bestScore then best,bestScore=c,score end
        end
    end
    return best,nearCount
end

--==================================================================
-- 🧠 AI 战斗大脑
--==================================================================
task.spawn(function()
    local blockHeld=false
    local lastM1,lastSkill,lastQ,lastUlt=0,0,0,0
    local parryUntil,dodgeUntil=0,0
    local enemyM1=setmetatable({},{__mode="k"}); local enemySk=setmetatable({},{__mode="k"})
    local skillRot=1; local kaIndex=0

    local function setBlock(on) if on and not blockHeld then kd(Enum.KeyCode.F); blockHeld=true elseif (not on) and blockHeld then ku(Enum.KeyCode.F); blockHeld=false end end
    local function faceTo(hrp,tt) local aim=tt.Position + (State.PredictAim and tt.AssemblyLinearVelocity*State.PredictLead or Vector3.zero); hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(aim.X,hrp.Position.Y,aim.Z)) end

    while ScreenGui.Parent do
        task.wait(0.03)
        local char,h,hrp=getChar()
        local manual=State.AutoCombo or State.AutoBlock
        local active=State.AIBrain or manual
        if not active or not(char and hrp and h and h.Health>0) then
            setBlock(false); HUD.state=State.AIBrain and "等待重生" or "待机"; HUD.action="—"; HUD.target="无"
        else
            local now=os.clock()
            local tgt,nearCount=pickTarget(hrp)
            local skills=readSkills()
            local myHP=h.Health/h.MaxHealth*100; HUD.hp=math.floor(myHP)
            local target=tgt and tgt.char; local thrp=tgt and tgt.t; local th=tgt and tgt.h
            local dist=thrp and (thrp.Position-hrp.Position).Magnitude or 999

            -- 预判信号
            local rec
            if target then rec=track(target)
                if dist<=34 then
                    local m1t=target:GetAttribute("LastM1Fire"); if m1t and enemyM1[target]~=m1t then enemyM1[target]=m1t; parryUntil=now+0.42 end
                    local skt=target:GetAttribute("LastSkill"); if skt and enemySk[target]~=skt then enemySk[target]=skt; dodgeUntil=now+0.5 end
                end
            end
            local reactBlock=State.ReactiveParry and now<parryUntil
            local reactDodge=State.SkillDodge and now<dodgeUntil
            if target and thrp and State.AutoFace then faceTo(hrp,thrp) end

            if State.AIBrain then
                HUD.target=target and tgt.name or "无"; HUD.dist=math.floor(dist); HUD.combo=char:GetAttribute("Combo") or 0
                HUD.enemyChar=target and (target:GetAttribute("Character") or "?") or "—"
                HUD.archetype=(target and rec) and archetype(target,rec) or "—"
                HUD.threat=(target and dist<=16) and "高" or (target and dist<=45 and "中" or "低")

                -- 1) 逃生(未开 KillAura 时才逃)
                if State.AutoEscape and myHP<=State.EscapeHP and target and not State.KillAura then
                    HUD.state="🛟逃生"; setBlock(true)
                    if State.AutoApproach then h:MoveTo(hrp.Position+(hrp.Position-thrp.Position).Unit*45) end
                    local up=State.UseSkills and pickRole(skills,"launcher"); if up and up.ready and dist<=12 then setBlock(false); useSkill(up.slot); HUD.action="挑空打断" end

                -- 2) ☠️ Kill Aura:瞬移轮流锁定全场,逐个连打(最接近全屏)
                elseif State.KillAura then
                    local inR={}
                    for _,e in ipairs(candidates()) do if (e.t.Position-hrp.Position).Magnitude<=State.KillAuraRange then inR[#inR+1]=e end end
                    if #inR>0 then
                        HUD.state="☠️KillAura"; HUD.action=#inR.."敌·轮转"; setBlock(false)
                        local ready=char:GetAttribute("M1Ready")
                        if (ready==nil or ready==true) and now-lastM1>=0.13 then
                            kaIndex=(kaIndex % #inR)+1; local e=inR[kaIndex]
                            hrp.CFrame=e.t.CFrame*CFrame.new(0,0,-2.6); faceTo(hrp,e.t); task.wait(0.02)
                            if e.char:GetAttribute("Blocking") and State.QGrab then useQ() else m1() end
                            lastM1=now
                            if State.UseSkills and now-lastSkill>=0.55 then local sk=pickRole(skills,"combo") or pickRole(skills,"launcher"); if sk and sk.ready then useSkill(sk.slot); lastSkill=now end end
                        end
                    else HUD.state="☠️KillAura·搜"; HUD.action="冲向最近"; if target and thrp then hrp.CFrame=thrp.CFrame*CFrame.new(0,0,-3); faceTo(hrp,thrp) end end

                -- 3) 1v多风筝(默认关,保守玩家可开)
                elseif State.KiteMultiple and nearCount>=2 then
                    HUD.state="🎯风筝(被围)"; setBlock(true); HUD.action="拉开+远程"
                    if State.AutoApproach and target then h:MoveTo(hrp.Position+(hrp.Position-thrp.Position).Unit*30) end
                    local rg=State.UseSkills and pickRole(skills,"ranged"); if rg and rg.ready and target then setBlock(false); faceTo(hrp,thrp); useSkill(rg.slot); HUD.action="远程:"..rg.name end

                -- 4) 闪避技能(可能破防)
                elseif reactDodge and target and thrp then
                    HUD.state="🌀闪避技能"; setBlock(true)
                    local side=(thrp.Position-hrp.Position).Unit:Cross(Vector3.new(0,1,0)); h:MoveTo(hrp.Position+side*14); HUD.action="侧移规避"

                -- 5) 反应格挡
                elseif reactBlock then setBlock(true); HUD.state="⚡完美格挡"; HUD.action="Block"

                -- 6) 输出/拆盾
                elseif target and thrp and dist<=State.ComboReach then
                    setBlock(false)
                    if State.HitboxTP then hrp.CFrame=CFrame.lookAt(thrp.Position-(thrp.Position-hrp.Position).Unit*2.5,Vector3.new(thrp.Position.X,hrp.Position.Y,thrp.Position.Z)) end
                    if target:GetAttribute("Blocking") then
                        -- 对面格挡 → Q 抓穿盾(核心克制)/破防技能
                        HUD.state="🤼拆盾"
                        if State.QGrab and now-lastQ>=1.4 then faceTo(hrp,thrp); useQ(); lastQ=now; HUD.action="Q抓取穿盾"
                        else local bb=State.UseSkills and pickRole(skills,"blockbreak"); if bb and bb.ready then useSkill(bb.slot); HUD.action="破防:"..bb.name; lastSkill=now else m1(); HUD.action="M1破盾" end end
                    else
                        HUD.state="⚔️连招输出"
                        local myCombo=char:GetAttribute("Combo") or 0
                        local ready=char:GetAttribute("M1Ready")
                        local m1Gap=math.clamp(0.42-State.Aggression*0.012,0.24,0.4)
                        if (ready==nil or ready==true) and not char:GetAttribute("Blocking") and now-lastM1>=m1Gap then m1(); lastM1=now; HUD.action="M1" end
                        -- 连招点:combo满接技能(挑空→连击→破防 轮转,冷却感知)
                        local skillGap=math.clamp(1.1-State.Aggression*0.06,0.5,1.1)
                        if State.UseSkills and now-lastSkill>=skillGap and myCombo>=3 then
                            local seq={}
                            if State.AutoLauncher then seq[#seq+1]=pickRole(skills,"launcher") end
                            seq[#seq+1]=pickRole(skills,"combo"); seq[#seq+1]=pickRole(skills,"blockbreak")
                            local fired=false
                            for off=0,#seq-1 do local idx=((skillRot-1+off)%math.max(#seq,1))+1; local sk=seq[idx]
                                if sk and sk.ready then useSkill(sk.slot); HUD.action="技能:"..sk.name; lastSkill=now; skillRot=idx+1; fired=true; break end end
                        end
                    end
                    -- 大招:对面残血/我方连招中
                    if State.AutoUlt and now-lastUlt>=2 then local ult=pickRole(skills,"ult"); if ult and ult.ready and th and th.Health/th.MaxHealth<0.5 then useSkill(ult.slot); HUD.action="💥"..ult.name; lastUlt=now end end

                -- 7) 追击(激进:TP锁身贴脸 / Q冲刺 / 跑,绝不原地防御)
                elseif target and thrp then
                    HUD.state="🏃追击"; setBlock(false)
                    if State.TPChase then
                        hrp.CFrame=thrp.CFrame*CFrame.new(0,0,(State.TPBehind and 2.6 or -2.6)); faceTo(hrp,thrp); HUD.action="🔒TP锁身"
                    elseif State.DashClose and dist>18 and now-lastQ>=1.1 then faceTo(hrp,thrp); useQ(); lastQ=now; HUD.action="Q冲刺"
                    elseif State.AutoApproach then h:MoveTo(thrp.Position); HUD.action="追击" end
                else HUD.state="🔍索敌"; HUD.action="—"; setBlock(false) end
            else
                -- 手动模式
                if reactBlock then setBlock(true); HUD.state="⚡反应格挡"
                elseif State.AutoCombo and target and thrp and dist<=State.ComboReach then setBlock(false)
                    local ready=char:GetAttribute("M1Ready"); if (ready==nil or ready==true) and not char:GetAttribute("Blocking") and now-lastM1>=0.3 then m1(); lastM1=now end; HUD.state="⚔️连招"
                elseif target and thrp then if State.AutoApproach then h:MoveTo(thrp.Position) end; setBlock(State.AutoBlock); HUD.state=State.AutoApproach and "🏃接近" or "索敌"
                else setBlock(State.AutoBlock); HUD.state=State.AutoBlock and "🛡️待命" or "索敌" end
                HUD.target=target and tgt.name or "无"; HUD.dist=math.floor(dist); HUD.combo=char:GetAttribute("Combo") or 0
            end
        end
    end
    setBlock(false)
end)

--==================================================================
-- 通用循环
--==================================================================
local flyBV,flyBG
local hbOrig=setmetatable({},{__mode="k"})
local HITBOXES={"Hitbox_RightArm","Hitbox_LeftArm","Hitbox_RightLeg","Hitbox_LeftLeg"}
local function startFly() local _,h,hrp=getChar(); if not hrp then return end; if flyBV then flyBV:Destroy() end if flyBG then flyBG:Destroy() end
    flyBV=new("BodyVelocity",{Parent=hrp,MaxForce=Vector3.new(1,1,1)*9e9,Velocity=Vector3.zero,P=1250}); flyBG=new("BodyGyro",{Parent=hrp,MaxTorque=Vector3.new(1,1,1)*9e9,P=9e4}); if h then h.PlatformStand=true end end
local function stopFly() if flyBV then flyBV:Destroy();flyBV=nil end if flyBG then flyBG:Destroy();flyBG=nil end local _,h=getChar(); if h then h.PlatformStand=false end end
bind("main",RunService.Heartbeat:Connect(function()
    local char,h,hrp=getChar(); if not char or not hrp then return end
    -- 命中盒扩大(实验性,需真人局验证服务端是否放行)
    for _,n in ipairs(HITBOXES) do local b=char:FindFirstChild(n)
        if b then if not hbOrig[b] then hbOrig[b]=b.Size end
            local sz=State.ReachSize
            if State.Reach then if (b.Size-Vector3.new(sz,sz,sz)).Magnitude>0.1 then b.Size=Vector3.new(sz,sz,sz) end
            elseif hbOrig[b] and (b.Size-hbOrig[b]).Magnitude>0.1 then b.Size=hbOrig[b] end end end
    if State.SpeedLock and h and h.WalkSpeed~=State.WalkSpeed and not State.AIBrain then h.WalkSpeed=State.WalkSpeed end
    if State.Noclip then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end end end
    if State.Fly then if not flyBV or flyBV.Parent~=hrp then startFly() end
        local dir=Vector3.zero; local look=Cam.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir+=look.LookVector end if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir-=look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir-=look.RightVector end if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir+=look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.new(0,1,0) end
        if flyBV then flyBV.Velocity=(dir.Magnitude>0 and dir.Unit or Vector3.zero)*State.FlySpeed end if flyBG then flyBG.CFrame=look end
    elseif flyBV then stopFly() end
    if State.AntiRag then if char:GetAttribute("Ragdoll") then pcall(function() char:SetAttribute("Ragdoll",false) end) end local r=char:FindFirstChild("Ragdoll"); if r then pcall(function() r:Destroy() end) end if h and h.Sit then h.Sit=false end end
    if State.AntiVoid and hrp.Position.Y<-50 then hrp.CFrame=CFrame.new(110,445,-11); hrp.AssemblyLinearVelocity=Vector3.zero end
end))
bind("hud",RunService.RenderStepped:Connect(function()
    if BrainHUD then local c=HUD.state:find("逃生") and T.danger or HUD.state:find("风筝") and T.warn or HUD.state:find("格挡") and T.on or HUD.state:find("闪避") and T.warn or (HUD.state:find("连招") or HUD.state:find("拆盾")) and T.accentB or T.text
        BrainHUD.Text=string.format("● 状态: %s\n◎ 目标: %s  [%dm]  威胁:%s\n◎ 敌方角色: %s  打法:%s\n◎ 我方连招: %d   血量:%d%%\n➤ 动作: %s",HUD.state,HUD.target,HUD.dist,HUD.threat,HUD.enemyChar,HUD.archetype,HUD.combo,HUD.hp,HUD.action)
        BrainHUD.TextColor3=c end
    if ComboHUD then local sk=readSkills(); local lines={"【我方技能】"}
        for _,s in ipairs(sk) do lines[#lines+1]=string.format("  [%d] %s  <%s>%s",s.slot,s.name,s.role,s.ready and "" or " (冷却)") end
        lines[#lines+1]=""; lines[#lines+1]="【敌方】"..HUD.enemyChar.." · 打法:"..HUD.archetype
        ComboHUD.Text=table.concat(lines,"\n") end
    if State.ESP then local _,_,my=getChar()
        for plr,f in pairs(ESPStore) do if plr.Parent and f.tl then local ch=plr.Character; local t=ch and ch:FindFirstChild("HumanoidRootPart")
            local s=plr.Name
            if State.ESPChar and ch then local cn=ch:GetAttribute("Character"); if cn then s=s.." ("..cn..")" end end
            if t and my and State.ESPDist then s=s.."  ["..math.floor((t.Position-my.Position).Magnitude).."m]" end
            f.tl.Text=s end end end
end))
bind("infjump",UserInputService.JumpRequest:Connect(function() if State.InfJump then local _,h=getChar(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end))
bind("espAdd",Players.PlayerAdded:Connect(function(p) if State.ESP then task.wait(0.5); makeESP(p) end end))
bind("espRem",Players.PlayerRemoving:Connect(function(p) if ESPStore[p] then ESPStore[p]:Destroy(); ESPStore[p]=nil end end))
bind("charAdd",LP.CharacterAdded:Connect(function() task.wait(1); if State.ESP then clearESP(); for _,p in ipairs(Players:GetPlayers()) do makeESP(p) end end end))
bind("afk",LP.Idled:Connect(function() if State.AntiAFK then pcall(function() local vu=game:GetService("VirtualUser"); vu:CaptureController(); vu:ClickButton2(Vector2.new()) end) end end))

-- 霓虹描边 + 底部辉光 + 快捷键 + 开场
bind("neon",RunService.RenderStepped:Connect(function()
    local t=tick()*0.14; local hue=t%1
    neonGrad.Color=ColorSequence.new(Color3.fromHSV(hue,0.7,1),Color3.fromHSV((hue+0.28)%1,0.7,1)); neonGrad.Rotation=(t*100)%360
    local gc=HUD.state:find("逃生") and T.danger or (HUD.state:find("连招") or HUD.state:find("拆盾")) and T.accentB or HUD.state:find("风筝") and T.warn or T.accentA
    underGlow.BackgroundColor3=gc; underGlow.BackgroundTransparency=0.15+0.15*math.sin(tick()*3)
end))
bind("togglekey",UserInputService.InputBegan:Connect(function(io,gpe) if gpe then return end if io.KeyCode==Enum.KeyCode.RightControl then Main.Visible=not Main.Visible end end))

selectTab("AI 大脑")
Main.Size=UDim2.fromOffset(0,0); Main.BackgroundTransparency=1
applyResponsiveLayout()
bind("viewportResize",Cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout))
TweenService:Create(Main,TweenInfo.new(0.4,Enum.EasingStyle.Back),{Size=UDim2.fromOffset(DESIGN_MAIN_SIZE.X,DESIGN_MAIN_SIZE.Y),BackgroundTransparency=0}):Play()
task.spawn(function()
    local noteWidth=isCompactViewport() and math.min(getViewportSize().X-32,280) or 300
    local noteX=isCompactViewport() and -16-noteWidth or -320
    local n=new("Frame",{Parent=ScreenGui,Size=UDim2.fromOffset(noteWidth,58),Position=UDim2.new(1,20,1,-84),BackgroundColor3=T.bg2},{corner(12),stroke(T.accentA,1.5)})
    new("TextLabel",{Parent=n,BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(1,-20,1,0),Font=Enum.Font.GothamBold,TextSize=13,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text="🧠 APEX OMNI v2 已加载\n行为自适应 AI · 右Ctrl 开关 · 配置已恢复"})
    TweenService:Create(n,TweenInfo.new(0.5,Enum.EasingStyle.Quint),{Position=UDim2.new(1,noteX,1,-84)}):Play()
    task.wait(4.5); TweenService:Create(n,TweenInfo.new(0.5),{Position=UDim2.new(1,20,1,-84)}):Play(); task.wait(0.6); n:Destroy()
end)
print("[APEX OMNI v2] 行为自适应 AI 大脑已加载 ✓")
