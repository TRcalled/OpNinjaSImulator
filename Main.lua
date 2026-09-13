task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end

    local Players      = game:GetService("Players")
    local RunService   = game:GetService("RunService")
    local HttpService  = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local TextService  = game:GetService("TextService")
    local CoreGui      = game:GetService("CoreGui")
    local VirtualUser  = game:GetService("VirtualUser")
    local LocalPlayer  = Players.LocalPlayer
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    --[[ ========================================================= ]]--
    --                     STATE & CONFIG VARIABLES                --
    --[[ ========================================================= ]]--
    getgenv().autotrain       = false
    getgenv().autoswing       = false
    getgenv().namechanger     = false
    getgenv().autoclick       = false
    getgenv().AntiAFKRunning  = false

    local FPSBoosterRepo = "https://raw.githubusercontent.com/TRcalled/TRFpsBooster/main/Main.lua"

    -- Auto-Upgrade Configuration State
    local SelectedUpgrades = {
        Sword     = false,
        Shuriken  = false,
        Class     = false,
        Ascend    = false
    }

    -- Webhook State
    local WebhookURL        = ""
    local WebhookEnabled    = false
    local WebhookInterval   = 60 
    local NextWebhookTime   = 0

    -- Combat Configuration
    local SelectedTargetName = nil
    local IsLoopTPEnabled    = false
    local CombatDistance     = 3
    local LoopConnection     = nil
    local TrainConnection    = nil 

    -- System UI Variables
    local PerformanceGui = nil
    local StatHUDEnabled = false

    --[[ ========================================================= ]]--
    --         DYNAMIC GUID & REMOTE RESOLVER ENGINE               --
    --[[ ========================================================= ]]--
    
    -- Returns PlayerGui safely
    local function GetPlayerGui()
        return LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    end

    -- Locates MainGui or its active instance
    local function GetMainGui()
        local playerGui = GetPlayerGui()
        if not playerGui then return nil end
        return playerGui:FindFirstChild("MainGui") or playerGui:FindFirstChildOfClass("ScreenGui")
    end

    -- Dynamically retrieves the Attack RemoteEvent (SwordSlash)
    local function GetAttackRemote()
        local playerGui = GetPlayerGui()
        if not playerGui then return nil end

        local mainGui = GetMainGui()
        if not mainGui then return nil end

        -- 1. Check if remote matches MainGui's dynamic Name
        local guidId = tostring(mainGui.Name)
        local directRemote = mainGui:FindFirstChild(guidId) or playerGui:FindFirstChild(guidId, true)
        if directRemote and directRemote:IsA("RemoteEvent") then
            return directRemote
        end

        -- 2. Search for any RemoteEvent child directly inside MainGui
        for _, child in ipairs(mainGui:GetChildren()) do
            if child:IsA("RemoteEvent") then
                return child
            end
        end

        -- 3. Fallback search across all PlayerGui ScreenGuis
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local remote = gui:FindFirstChildOfClass("RemoteEvent")
                if remote then return remote end
            end
        end

        return nil
    end

    -- Dynamically retrieves the Name Changer RemoteFunction (ChangeName)
    local function GetNameRemote()
        local playerGui = GetPlayerGui()
        if not playerGui then return nil end

        local mainGui = GetMainGui()
        if not mainGui then return nil end

        -- 1. Search for any RemoteFunction child inside MainGui
        for _, child in ipairs(mainGui:GetChildren()) do
            if child:IsA("RemoteFunction") then
                return child
            end
        end

        -- 2. Fallback search across all PlayerGui ScreenGuis
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local remote = gui:FindFirstChildOfClass("RemoteFunction")
                if remote then return remote end
            end
        end

        return nil
    end

    --[[ ========================================================= ]]--
    --                   UTILITY FUNCTIONS                         --
    --[[ ========================================================= ]]--
    local function isRGB(color3, r, g, b)
        if not color3 then return false end
        local cr = math.floor(color3.R * 255 + 0.5)
        local cg = math.floor(color3.G * 255 + 0.5)
        local cb = math.floor(color3.B * 255 + 0.5)
        return cr == r and cg == g and cb == b
    end

    local function press(btn)
        if not btn or not btn.Visible then return end
        pcall(firesignal, btn.MouseButton1Down)
        task.wait()
        pcall(firesignal, btn.MouseButton1Up)
        pcall(firesignal, btn.MouseButton1Click)
    end

    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Name ~= "" then
                table.insert(names, p.Name)
            end
        end
        if #names == 0 then table.insert(names, "No other players found") end
        return names
    end

    local function getStatValue(path, key)
        local folder = LocalPlayer:FindFirstChild(path)
        local stat = folder and folder:FindFirstChild(key)
        return stat and stat.Value or 0
    end

    local suffixes = {
        {1e120, "NoTg"}, {1e117, "OcTg"}, {1e114, "SpTg"}, {1e111, "SxTg"}, {1e108, "QnTg"}, {1e105, "QdTg"}, {1e102, "TTg"}, {1e99, "DTg"}, {1e96, "UTg"}, {1e93, "Tg"},
        {1e90, "NoVt"}, {1e87, "OcVt"}, {1e84, "SpVt"}, {1e81, "SxVt"}, {1e78, "QnVt"}, {1e75, "QdVt"}, {1e72, "TVt"}, {1e69, "DVt"}, {1e66, "UVt"}, {1e63, "Vt"},
        {1e60, "NoDe"}, {1e57, "OcDe"}, {1e54, "SpDe"}, {1e51, "SxDe"}, {1e48, "QnDe"}, {1e45, "QdDe"}, {1e42, "TDe"}, {1e39, "DDe"}, {1e36, "UDe"}, {1e33, "De"},
        {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"}, {1e18, "Qn"}, {1e15, "Qd"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
    }

    local function formatNumber(num)
        num = tonumber(num) or 0
        if num < 1000 then return tostring(num) end
        for _, v in ipairs(suffixes) do
            if num >= v[1] then
                return string.format("%.2f%s", num / v[1], v[2])
            end
        end
        return tostring(num)
    end

    -- Initial Statistics Tracking
    local initialStats = {
        Ninjutsu  = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0,
        SoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0,
        Power     = tonumber(getStatValue("leaderstats", "Power")) or 0,
        Realm     = tostring(getStatValue("leaderstats", "Realm"))
    }

    local previousStats = {
        Ninjutsu  = initialStats.Ninjutsu,
        SoulForce = initialStats.SoulForce,
        Power     = initialStats.Power,
        Realm     = initialStats.Realm
    }

    --[[ ========================================================= ]]--
    --            CUSTOM NOTIFICATION OVERLAY                      --
    --[[ ========================================================= ]]--
    local NotificationGui = Instance.new("ScreenGui")
    NotificationGui.Name = "NinjaHubNotificationOverlay"
    NotificationGui.ResetOnSpawn = false
    if not pcall(function() NotificationGui.Parent = CoreGui end) then
        NotificationGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local NotificationContainer = Instance.new("Frame", NotificationGui)
    NotificationContainer.Name = "Container"
    NotificationContainer.Size = UDim2.new(0, 260, 0, 500)
    NotificationContainer.Position = UDim2.new(1, -280, 0, 210)
    NotificationContainer.BackgroundTransparency = 1

    local NotificationList = Instance.new("UIListLayout", NotificationContainer)
    NotificationList.SortOrder = Enum.SortOrder.LayoutOrder
    NotificationList.VerticalAlignment = Enum.VerticalAlignment.Top
    NotificationList.Padding = UDim.new(0, 8)

    local function CustomNotify(title, content, duration)
        duration = duration or 3.5
        
        local Frame = Instance.new("Frame", NotificationContainer)
        Frame.Size = UDim2.new(1, 0, 0, 55)
        Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Frame.BackgroundTransparency = 1
        
        local Corner = Instance.new("UICorner", Frame)
        Corner.CornerRadius = UDim.new(0, 6)
        
        local Stroke = Instance.new("UIStroke", Frame)
        Stroke.Color = Color3.fromRGB(0, 140, 255)
        Stroke.Thickness = 1.2
        Stroke.Transparency = 1

        local TitleLabel = Instance.new("TextLabel", Frame)
        TitleLabel.Size = UDim2.new(1, -20, 0, 20)
        TitleLabel.Position = UDim2.new(0, 12, 0, 6)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.Text = string.upper(title)
        TitleLabel.TextColor3 = Color3.fromRGB(0, 140, 255)
        TitleLabel.TextSize = 11
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.TextTransparency = 1

        local ContentLabel = Instance.new("TextLabel", Frame)
        ContentLabel.Size = UDim2.new(1, -24, 0, 24)
        ContentLabel.Position = UDim2.new(0, 12, 0, 24)
        ContentLabel.BackgroundTransparency = 1
        ContentLabel.Font = Enum.Font.GothamMedium
        ContentLabel.Text = content
        ContentLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
        ContentLabel.TextSize = 11
        ContentLabel.TextXAlignment = Enum.TextXAlignment.Left
        ContentLabel.TextWrapped = true
        ContentLabel.TextTransparency = 1

        TweenService:Create(Frame, TweenInfo.new(0.25), {BackgroundTransparency = 0.15}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.25), {Transparency = 0.4}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
        TweenService:Create(ContentLabel, TweenInfo.new(0.25), {TextTransparency = 0}):Play()

        task.delay(duration, function()
            if not Frame or not Frame.Parent then return end
            local fadeOut = TweenService:Create(Frame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
            TweenService:Create(Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
            TweenService:Create(TitleLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(ContentLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            fadeOut:Play()
            fadeOut.Completed:Wait()
            Frame:Destroy()
        end)
    end

    --[[ ========================================================= ]]--
    --                 ON-SCREEN STAT TRACKER HUD                   --
    --[[ ========================================================= ]]--
    local function CreateStatHUD()
        if PerformanceGui then PerformanceGui:Destroy() end

        PerformanceGui = Instance.new("ScreenGui")
        PerformanceGui.Name = "NinjaHubStatTrackerHUD"
        PerformanceGui.ResetOnSpawn = false
        if not pcall(function() PerformanceGui.Parent = CoreGui end) then
            PerformanceGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local Container = Instance.new("Frame", PerformanceGui)
        Container.Size = UDim2.new(0, 320, 0, 75)
        Container.Position = UDim2.new(0.5, -160, 0, 15)
        Container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Container.BackgroundTransparency = 0.2

        local Corner = Instance.new("UICorner", Container)
        Corner.CornerRadius = UDim.new(0, 8)

        local Stroke = Instance.new("UIStroke", Container)
        Stroke.Color = Color3.fromRGB(0, 140, 255)
        Stroke.Thickness = 1.5

        local Title = Instance.new("TextLabel", Container)
        Title.Size = UDim2.new(1, 0, 0, 22)
        Title.Position = UDim2.new(0, 0, 0, 4)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "NINJA HUB | REAL-TIME STAT TELEMETRY"
        Title.TextColor3 = Color3.fromRGB(0, 140, 255)
        Title.TextSize = 11

        local StatLabel = Instance.new("TextLabel", Container)
        StatLabel.Name = "StatDisplay"
        StatLabel.Size = UDim2.new(1, -20, 0, 40)
        StatLabel.Position = UDim2.new(0, 10, 0, 28)
        StatLabel.BackgroundTransparency = 1
        StatLabel.Font = Enum.Font.GothamMedium
        StatLabel.Text = "Ninjutsu: +0/s | Soul Force: +0/s\nPower: +0/s | Realm: Unchanged"
        StatLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        StatLabel.TextSize = 11
        StatLabel.TextWrapped = true

        PerformanceGui.Enabled = StatHUDEnabled
    end

    CreateStatHUD()

    task.spawn(function()
        while true do
            task.wait(1)
            local currentNinjutsu  = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
            local currentSoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
            local currentPower     = tonumber(getStatValue("leaderstats", "Power")) or 0
            local currentRealm     = tostring(getStatValue("leaderstats", "Realm"))

            local diffNinjutsu  = currentNinjutsu - previousStats.Ninjutsu
            local diffSoulForce = currentSoulForce - previousStats.SoulForce
            local diffPower     = currentPower - previousStats.Power

            previousStats.Ninjutsu  = currentNinjutsu
            previousStats.SoulForce = currentSoulForce
            previousStats.Power     = currentPower
            previousStats.Realm     = currentRealm

            if PerformanceGui and PerformanceGui:FindFirstChild("Frame") then
                local statDisplay = PerformanceGui.Frame:FindFirstChild("StatDisplay")
                if statDisplay then
                    statDisplay.Text = string.format(
                        "Ninjutsu: +%s/s | Soul Force: +%s/s\nPower: +%s/s | Realm: %s",
                        formatNumber(diffNinjutsu),
                        formatNumber(diffSoulForce),
                        formatNumber(diffPower),
                        currentRealm
                    )
                end
            end
        end
    end)

    --[[ ========================================================= ]]--
    --                 DISCORD WEBHOOK TELEMETRY                   --
    --[[ ========================================================= ]]--
    local function sendStatsWebhook(statusType)
        if not WebhookEnabled or WebhookURL == "" then return end

        local curNinjutsu  = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
        local curSoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
        local curPower     = tonumber(getStatValue("leaderstats", "Power")) or 0
        local curRealm     = tostring(getStatValue("leaderstats", "Realm"))

        local gainsNinjutsu  = curNinjutsu - initialStats.Ninjutsu
        local gainsSoulForce = curSoulForce - initialStats.SoulForce
        local gainsPower     = curPower - initialStats.Power

        local payload = {
            embeds = {{
                title = "Ninja Hub Telemetry Report",
                color = 35983,
                fields = {
                    {name = "Player", value = LocalPlayer.Name, inline = true},
                    {name = "Status", value = statusType or "Active", inline = true},
                    {name = "Realm", value = curRealm, inline = true},
                    {name = "Current Ninjutsu", value = formatNumber(curNinjutsu), inline = true},
                    {name = "Current Soul Force", value = formatNumber(curSoulForce), inline = true},
                    {name = "Current Power", value = formatNumber(curPower), inline = true},
                    {name = "Session Gains (Ninjutsu)", value = "+" .. formatNumber(gainsNinjutsu), inline = true},
                    {name = "Session Gains (Soul Force)", value = "+" .. formatNumber(gainsSoulForce), inline = true},
                    {name = "Session Gains (Power)", value = "+" .. formatNumber(gainsPower), inline = true}
                },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }

        pcall(function()
            local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
            if requestFunc then
                requestFunc({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(payload)
                })
            end
        end)
    end

    task.spawn(function()
        while true do
            task.wait(1)
            if WebhookEnabled and tick() >= NextWebhookTime then
                sendStatsWebhook("Scheduled Update")
                NextWebhookTime = tick() + WebhookInterval
            end
        end
    end)

    --[[ ========================================================= ]]--
    --         FAST HEARTBEAT ATTACK & NAME CHANGER THREADS        --
    --[[ ========================================================= ]]--

    -- 1. Fast Heartbeat Auto-Swing Loop (Auto-resolved Remote)
    task.spawn(function()
        while true do
            RunService.Heartbeat:Wait()
            if getgenv().autoswing then
                local attackRemote = GetAttackRemote()
                if attackRemote then
                    pcall(function()
                        attackRemote:FireServer("SwordSlash", 1)
                    end)
                end
            end
        end
    end)

    -- 2. Mysterious / ASCII Name Changer (0.5s Loop)
    local CoolNames = {
        "⚡ 𝓥𝓞𝓘𝓓 ⚡",
        "☬ 𝑆𝐻𝐴𝐷𝑂𝑊 ☬",
        "☠ 𝔈𝔑ℑ𝔊𝔐𝔄 ☠",
        "⚔ 𝕹𝕴𝕹𝕵𝕬 ⚔",
        "✦ 𝑆𝑂𝑈𝐿 ✦",
        "✧ 𝕻𝕳𝕬𝕹𝕿𝕺𝕸 ✧",
        "[ ? ? ? ]",
        "░▒▓ 𝕲𝕳𝕺𝕾𝕿 ▓▒░",
        "【 𝕬𝕭𝖄𝕾𝕾 】",
        "ᛖ 𝕍𝕆𝕀𝔻𝕎𝔸𝕃𝕂𝔼ℝ ᛖ",
        "彡 𝓚𝓐𝓣𝓐𝓝𝓐 彡",
        "᚛ 𝕹𝕴𝕲𝕳𝕿𝕱𝕬𝕷𝕷 ᚜",
        "† 𝕰𝕮𝕷𝕴𝕻𝕾𝕰 †",
        "☣ 𝕽𝕰𝕬𝕻𝕰𝕽 ☣",
        "★ 𝓘𝓝𝓕𝓘𝓝𝓘𝓣𝓨 ★"
    }

    task.spawn(function()
        while true do
            task.wait(0.5)
            if getgenv().namechanger then
                local nameRemote = GetNameRemote()
                if nameRemote then
                    local randomName = CoolNames[math.random(1, #CoolNames)]
                    pcall(function()
                        nameRemote:InvokeServer("ChangeName", randomName)
                    end)
                end
            end
        end
    end)

    --[[ ========================================================= ]]--
    --                     AUTOMATION LOOPS                        --
    --[[ ========================================================= ]]--

    -- Pop-up Removal Click Loop
    task.spawn(function()
        while true do
            if getgenv().autoclick then
                local playerGui = GetPlayerGui()
                if playerGui then
                    local pvpBtn = playerGui:FindFirstChild("PvPProtectionHud", true) and playerGui.PvPProtectionHud:FindFirstChild("Btn")
                    local randomSpawnBtn = playerGui:FindFirstChild("SpawnF", true) and playerGui.SpawnF:FindFirstChild("RandomSpawnImgBtn")
                    press(pvpBtn)
                    press(randomSpawnBtn)
                end
            end
            task.wait(.1)
        end
    end)

    -- Dynamic Auto-Upgrade Color Trigger Engine & UI Auto-Dismissal Loop
    task.spawn(function()
        while true do
            task.wait()
            
            local playerGui = GetPlayerGui()
            if not playerGui then continue end
            
            local mainGui = GetMainGui()
            if not mainGui then continue end

            -- Auto-Close Upgrade Failure UI Prompts
            local failedFrames = {"UpgradeFailedF", "UpgradeClassFailedF", "UpgradeAscensionFailedF"}
            for _, frameName in ipairs(failedFrames) do
                local failedFrame = mainGui:FindFirstChild(frameName)
                if failedFrame and failedFrame.Visible then
                    local closeBtn = failedFrame:FindFirstChild("NoImgBtn")
                    if closeBtn then
                        press(closeBtn)
                    end
                end
            end

            -- Color Detection Logic
            local upgradeF = mainGui:FindFirstChild("UpgradeF")
            if upgradeF then
                -- Sword Auto Upgrade
                if SelectedUpgrades["Sword"] then
                    local swordBtn = upgradeF:FindFirstChild("SwordF") and upgradeF.SwordF:FindFirstChild("MaxUpgradeBtn")
                    if swordBtn and not isRGB(swordBtn.ImageColor3, 0, 20, 0) then
                        press(swordBtn)
                    end
                end

                -- Shuriken Auto Upgrade
                if SelectedUpgrades["Shuriken"] then
                    local shurikenBtn = upgradeF:FindFirstChild("ShurikenF") and upgradeF.ShurikenF:FindFirstChild("ShurikenImgBtn")
                    if shurikenBtn and not isRGB(shurikenBtn.ImageColor3, 0, 20, 0) then
                        press(shurikenBtn)
                    end
                end

                -- Class Auto Upgrade
                if SelectedUpgrades["Class"] then
                    local classBtn = upgradeF:FindFirstChild("ClassF") and upgradeF.ClassF:FindFirstChild("ClassImgBtn")
                    if classBtn and not isRGB(classBtn.ImageColor3, 0, 0, 105) then
                        press(classBtn)
                    end
                end

                -- Ascend Auto Upgrade
                if SelectedUpgrades["Ascend"] then
                    local ascendBtn = upgradeF:FindFirstChild("AscendF") and upgradeF.AscendF:FindFirstChild("AscendImgBtn")
                    if ascendBtn and not isRGB(ascendBtn.ImageColor3, 0, 0, 105) then
                        press(ascendBtn)
                    end
                end
            end
        end
    end)

    -- Built-in Anti-AFK Fallback Hook
    LocalPlayer.Idled:Connect(function()
        if getgenv().AntiAFKRunning then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)

    --[[ ========================================================= ]]--
    --                        RAYFIELD UI                          --
    --[[ ========================================================= ]]--
    local Window = Rayfield:CreateWindow({
        Name = "Ninja Hub | Ultimate Edition",
        LoadingTitle = "Ninja Hub Loading...",
        LoadingSubtitle = "by Ninja Hub Team",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "NinjaHubConfigs",
            FileName = "NinjaHub_Config"
        },
        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = true
        },
        KeySystem = false
    })

    -- 1. Main / Auto Farming Tab
    local MainTab = Window:CreateTab("Auto Farming", 4483362458)

    MainTab:CreateToggle({
        Name = "Heartbeat Auto-Swing (Dynamic Remote)",
        CurrentValue = false,
        Flag = "HeartbeatAutoSwingToggle",
        Callback = function(Value)
            getgenv().autoswing = Value
            CustomNotify("Auto Swing", Value and "Fast Heartbeat Auto-Swing Enabled" or "Auto-Swing Disabled", 3)
        end,
    })

    MainTab:CreateToggle({
        Name = "Tool Auto Train (RenderStepped)",
        CurrentValue = false,
        Flag = "AutoTrainToggle",
        Callback = function(Value)
            getgenv().autotrain = Value
            if Value then
                TrainConnection = RunService.RenderStepped:Connect(function()
                    if getgenv().autotrain and LocalPlayer.Character then
                        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            tool:Activate()
                        end
                    end
                end)
                CustomNotify("Auto Train", "Auto Train active at max FPS speed", 3)
            else
                if TrainConnection then
                    TrainConnection:Disconnect()
                    TrainConnection = nil
                end
                CustomNotify("Auto Train", "Auto Train disabled", 3)
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Click Pop-ups",
        CurrentValue = false,
        Flag = "AutoClickToggle",
        Callback = function(Value)
            getgenv().autoclick = Value
            CustomNotify("Auto Click", Value and "Auto Clicking Pop-ups Enabled" or "Auto Clicking Disabled", 3)
        end,
    })

    MainTab:CreateDropdown({
        Name = "Select Auto Upgrade Types",
        Options = {"Sword", "Shuriken", "Class", "Ascend"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "AutoUpgradeDropdown",
        Callback = function(Options)
            SelectedUpgrades["Sword"]    = false
            SelectedUpgrades["Shuriken"] = false
            SelectedUpgrades["Class"]    = false
            SelectedUpgrades["Ascend"]   = false
            
            for _, opt in ipairs(Options) do
                if SelectedUpgrades[opt] ~= nil then
                    SelectedUpgrades[opt] = true
                end
            end
            CustomNotify("Auto Upgrade", "Updated target upgrade selections", 2.5)
        end,
    })

    MainTab:CreateButton({
        Name = "Create Safe Zone Platform",
        Callback = function()
            local platform = Instance.new("Part")
            platform.Name = "NinjaHubSafeZone"
            platform.Size = Vector3.new(20, 1, 20)
            platform.Position = Vector3.new(0, 50, 10000)
            platform.Anchored = true
            platform.Material = Enum.Material.SmoothPlastic
            platform.Parent = workspace

            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = platform.CFrame + Vector3.new(0, 3, 0)
                CustomNotify("Safe Zone", "Teleported to Safe Zone Platform", 3)
            end
        end,
    })

    -- 2. Combat Tab
    local CombatTab = Window:CreateTab("Combat & TP", 4483362458)

    local PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Select Player Target",
        Options = getPlayerNames(),
        CurrentOption = {"None"},
        MultipleOptions = false,
        Flag = "TargetPlayerDropdown",
        Callback = function(Option)
            SelectedTargetName = Option[1] or Option
            CustomNotify("Target Lock", "Selected Target: " .. tostring(SelectedTargetName), 3)
        end,
    })

    CombatTab:CreateButton({
        Name = "Refresh Player List",
        Callback = function()
            PlayerDropdown:Refresh(getPlayerNames())
            CustomNotify("Combat", "Player list refreshed", 2)
        end,
    })

    CombatTab:CreateSlider({
        Name = "Combat Teleport Distance",
        Range = {1, 10},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = 3,
        Flag = "CombatDistanceSlider",
        Callback = function(Value)
            CombatDistance = Value
        end,
    })

    CombatTab:CreateToggle({
        Name = "Loop TP Behind Target",
        CurrentValue = false,
        Flag = "LoopTPToggle",
        Callback = function(Value)
            IsLoopTPEnabled = Value
            if Value then
                LoopConnection = RunService.Heartbeat:Connect(function()
                    if IsLoopTPEnabled and SelectedTargetName and SelectedTargetName ~= "No other players found" then
                        local targetPlayer = Players:FindFirstChild(SelectedTargetName)
                        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local targetHRP = targetPlayer.Character.HumanoidRootPart
                                LocalPlayer.Character.HumanoidRootPart.CFrame = targetHRP.CFrame * CFrame.new(0, 0, CombatDistance)
                            end
                        end
                    end
                end)
                CustomNotify("Combat", "Loop TP Enabled for target: " .. tostring(SelectedTargetName), 3)
            else
                if LoopConnection then
                    LoopConnection:Disconnect()
                    LoopConnection = nil
                end
                CustomNotify("Combat", "Loop TP Disabled", 3)
            end
        end,
    })

    -- 3. Telemetry / Stat Tracker Tab
    local TelemetryTab = Window:CreateTab("Telemetry", 4483362458)

    TelemetryTab:CreateToggle({
        Name = "Enable On-Screen Stat HUD",
        CurrentValue = false,
        Flag = "StatHUDToggle",
        Callback = function(Value)
            StatHUDEnabled = Value
            if PerformanceGui then
                PerformanceGui.Enabled = Value
            end
            CustomNotify("HUD Overlay", Value and "Stat HUD Enabled" or "Stat HUD Disabled", 2.5)
        end,
    })

    TelemetryTab:CreateInput({
        Name = "Discord Webhook URL",
        PlaceholderText = "Paste Webhook URL Here",
        RemoveTextOnFocus = false,
        Callback = function(Text)
            WebhookURL = Text
            CustomNotify("Webhook", "Webhook URL updated", 2.5)
        end,
    })

    TelemetryTab:CreateToggle({
        Name = "Enable Discord Webhook",
        CurrentValue = false,
        Flag = "WebhookToggle",
        Callback = function(Value)
            WebhookEnabled = Value
            if Value then
                NextWebhookTime = tick()
                CustomNotify("Webhook", "Discord Webhook Logging Enabled", 3)
            else
                CustomNotify("Webhook", "Discord Webhook Logging Disabled", 3)
            end
        end,
    })

    TelemetryTab:CreateSlider({
        Name = "Webhook Interval (Seconds)",
        Range = {10, 300},
        Increment = 5,
        Suffix = "s",
        CurrentValue = 60,
        Flag = "WebhookIntervalSlider",
        Callback = function(Value)
            WebhookInterval = Value
        end,
    })

    TelemetryTab:CreateButton({
        Name = "Send Test Webhook Report",
        Callback = function()
            if WebhookURL ~= "" then
                sendStatsWebhook("Manual Test")
                CustomNotify("Webhook", "Test Webhook sent successfully!", 3)
            else
                CustomNotify("Webhook Error", "Please input a valid Webhook URL first", 3)
            end
        end,
    })

    -- 4. Misc & Tools Tab
    local MiscTab = Window:CreateTab("Misc & Tools", 4483362458)

    MiscTab:CreateToggle({
        Name = "Mysterious ASCII Name Changer (0.5s)",
        CurrentValue = false,
        Flag = "NameChangerToggle",
        Callback = function(Value)
            getgenv().namechanger = Value
            CustomNotify("Name Changer", Value and "Mysterious Name Cycler Activated" or "Name Cycler Disabled", 3)
        end,
    })

    MiscTab:CreateToggle({
        Name = "Anti-AFK Protection (Local Hook)",
        CurrentValue = false,
        Flag = "AntiAFKToggle",
        Callback = function(Value)
            getgenv().AntiAFKRunning = Value
            CustomNotify("Anti-AFK", Value and "Anti-AFK Enabled" or "Anti-AFK Disabled", 3)
        end,
    })

    MiscTab:CreateButton({
        Name = "Launch External FPS Booster & Anti-AFK Suite",
        Callback = function()
            pcall(function()
                loadstring(game:HttpGet(FPSBoosterRepo))()
            end)
            CustomNotify("Optimizer", "FPS Booster & Anti-AFK Suite Loaded", 3)
        end,
    })

    CustomNotify("Ninja Hub", "Ninja Hub | Ultimate Edition Loaded Successfully!", 4)
end)
