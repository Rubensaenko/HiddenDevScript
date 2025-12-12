local HiddenDev = {}

-- The planet moves to the mouse cursor's location, 
--and if there are enemies in the area, the player can
--either left-click to activate an attack (you can charge it) or right-click for a combo
--to perform another attack. I added an extra attack on 
--the right-click to allow players to perform a really 
--cool combo. Of course, I didn't push the VFX, animation,
--sound, or even the movements at all, but I can create a 
--much more complex script with math if needed. However, 
--I limited myself to a time of 3 hours to make this 
--because its is a commision.

-- Variables
local spell_State = {}
local spell_Cooldown = {}
-- Modules
local Inventory_Module = require(game.ReplicatedStorage.Module.Inventory):GetInstance()
local Orbite_Module = require(game.ReplicatedStorage.Module.OrbiteModule)
-- Service 
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
-- Remotes
local ActionRemote = game.ReplicatedStorage.ActionSpell
local StartSpell = game.ReplicatedStorage.StartSpell
local ActionSpellADvanced = game.ReplicatedStorage.ActionSpellADvanced

-- Confif  

-- Here is the config for the spell like the big manual, and here we can add more sequence, change stuff, etc etc

local config =  {

	AstralCollapse = {
		Id = "AstralCollapse",
		Type = "Ultimate",
		Category = "Astral",

		ManaCost = 60,
		Cooldown = 20,
		MaxCharges = 1,
		ChargeRegen = 0,
		
		Scaling = {
			Power = 1.8,
			LevelMultiplier = 0.12,
		},

		Cast = {
			Time = 1.2,
			CanMove = false,
			CanRotate = true,
			CancelOnStun = true,
			VFX = "AstralCastCharge",
		},

		Sequence = {

			Phase1 = {
				Delay = 0.2,
				Action = "SpawnZone",
				Params = {
					Radius = 8,
					Duration = 1.5,
					VFX = "AstralZone",
					DamageOverTime = {
						Tick = 0.5,
						Amount = 6,
						Scaling = 0.2
					}
				}
			},

			Phase2 = {
				Delay = 1.5,
				Action = "PullEnemies",
				Params = {
					Force = math.huge,
					Radius = 10,
					Duration = 0.6,
					VFX = "AstralPull",
					Sound = "PullWhirl"
				}
			},

			Phase3 = {
				Delay = 0.6,
				Action = "Explosion",
				Params = {
					Radius = 12,
					Damage = 45,
					Scaling = 0.8,
					Knockback = 25,
					VFX = "AstralExplode",
					CameraShake = "Explosion",
					Sound = "AstralBoom"
				}
			}
		},

		Conditions = {
			MustBeGrounded = false,
			RequireElement = { "Air", "Void" },
			BlockedBy = { "Silence", "Stun" }
		},

		Buffs = {
			SelfBuff = {
				Stat = "Speed",
				Mult = 1.15,
				Duration = 3,
			},
			EnemyDebuff = {
				Stat = "Defense",
				Mult = 0.85,
				Duration = 4,
			}
		},

		Interactions = {
			Reaction = {
				Vaporize = {
					With = "Fire",
					Bonus = 1.4
				},

				FreezeCombo = {
					With = "Ice",
					ExtraEffect = "Shatter",
					ExtraDamage = 25
				},

			}
		},

		Runtime = {
			TrackEnemies = true,
			TickRate = 0.1,
			AllowCrits = true,
			CritMultiplier = 1.8
		},
	}

}



function HiddenDev:Resolver(player,mousetarget,mousepart)
	local cooldwon = spell_Cooldown[player.UserId]
	-- check if the player is in the cooldown table if yes then we cancel 
	if cooldwon then
		print("Cooldwon !")
		return false
	end
	-- check the mousetarget and if is nil so we cancel,for no bug like when we click in the sky or something is nil 
	if mousetarget == nil then
		print("Mouse target is nil !")
		return
	end
	-- we verify the player is alive and if the character is not nil, avoid error when the player spam the spell when the character is not ready
	local Hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not Hrp or not Hrp.Parent.Humanoid then
		return
	end
	-- check if the player is in the air or not, i add this for more realism but you can remove it if you want
	local Hum = Hrp.Parent:FindFirstChild("Humanoid")
	if Hum:GetState() == Enum.HumanoidStateType.Freefall then
		print("Freefall !")
		return
	end 
	
	-- We can add more checks here if needed/ depend of the game mechanics
	spell_State[player.UserId] = "SpellReady"
	
	return true
end


function HiddenDev:Applier (player,mousetarget,spawnpoint,planet,mousepart)
	-- here we verify if the mouse click in the planet or not
	if mousepart == planet.TablePoo.Part then
		-- if he click on the planet then we return, cause we dont want to start the spell in the planet
		return
	end
	-- we add the player in the cooldwon table for avoid spamming the spell
	spell_Cooldown[player.UserId] = true

	-- disconnect the planet orbite for allow to the planet to move in the space freely
	local projectil = planet.TablePoo.Part
	planet.TablePoo.Orbite:Disconnect()

	local ConnectRunservice
	-- here im using runservice.hearbeat for moving the planet and lerp 
	 ConnectRunservice = RunService.Heartbeat:Connect(function()
		local projectil = planet.TablePoo.Part
		-- lerp gonna allow to split the cframe in to mini cframe and make the movement more smooth we can change the split value for more or less smoothness
		-- here its 0.10 but you can change it to 0.01 or 0.20 for more smoothness or not
		projectil.CFrame = projectil.CFrame:Lerp(mousetarget,0.10)
		
		-- then we gonna calculate the distance between the planet and the mouse target
		local distance = (mousetarget.Position - projectil.Position).Magnitude
		-- if the distance is less or equal to 3 then we disconnect the runservice and start the zone because the planet is close enough to the mouse target
		
		if distance <= 3 then
			-- we disconnect the runservice for no bug and start the zone
			ConnectRunservice:Disconnect()
			
			HiddenDev:CreatZone(player,mousetarget,planet)
		end
	end)
end

function HiddenDev:CreatZone(player,mousetarget,planet)
	-- Create the zone and place in the center forthe mousetarget and detect the enemies with touched event
	local zone = game.ReplicatedStorage.ZonePart:Clone()
	zone.Position = Vector3.new(mousetarget.Position.X,0,mousetarget.Position.Z)
	zone.Parent = workspace
	
	local ennemie = {}
	local rayon = math.pi * zone.Size.Z / 2 * zone.Size.Z / 2 
	
	zone.Touched:Connect(function(hit)
		if hit.Parent:FindFirstChild("Humanoid") and hit.Parent:FindFirstChild("HumanoidRootPart") then
			if hit.Parent == player.Character then
				return
			end
			if not table.find(ennemie,hit.Parent) then
				table.insert(ennemie,hit.Parent)
				print(ennemie)
			end
		end
	end)
	
	task.wait(0.2)
	for o, Ennemies in pairs(ennemie) do 
		print("BAHAHAHAHAHHAHAHAHA")
		local hum
		-- Check if the enemy is a player or a NPC with IsA("Player")
		if Ennemies:IsA("Player") then
			hum = Ennemies.Character:FindFirstChild("Humanoid")
		else
			hum = Ennemies:FindFirstChild("Humanoid")
		end
		-- if hum exist then
		if hum then
			-- Add effect to the enemy by the effect module or something
			-- like Stun enenmy 
			-- or apply damage to the enemy
			local basespeed = hum.WalkSpeed
			local baseJumpPower = hum.JumpPower
			hum.WalkSpeed = 0
			hum.JumpPower = 0

			task.delay(config.AstralCollapse.Sequence.Phase1.Params.Duration,function()
				hum.WalkSpeed = basespeed
				hum.JumpPower = baseJumpPower
			end)
		end
	end
	-- Check if the ennemie is empty with table.getn its gonna return 0 if its empty
	if table.getn(ennemie) == 0 then
		print("Aucun ennemie dans la zone")
		HiddenDev:Stopped(player,planet,zone)
		return
	end
	-- and if all its good then connect the event with the action remote
	HiddenDev:ConnectEvent(player,planet,zone,ennemie)
	ennemie = {}
end

function HiddenDev:ConnectEvent(player,planet,zone,ennemie)
	local actionPlayer
	-- call first time for activate the remotes
	ActionRemote:FireClient(player,"Good")
	
	local starttime = tick()
	-- then we wait the remots responce (left click or right click)
	ActionRemote.OnServerEvent:Connect(function(player,action)
		actionPlayer = action
		print(action)
	end)
	-- creat a loop to check if the player do something or not , and if not we wait until > 5 second
	while not actionPlayer do
		if tick() - starttime >= 5  and not actionPlayer then
			-- if the player do nothing then we stop the spell
			ActionRemote:FireClient(player,"Stopped")
			HiddenDev:Stopped(player,planet,zone)
			break
		end
		task.wait()
	end
	local index = 0
	-- here its the action of the player so if left then boom, or right then boom
	if actionPlayer == "Left" then
		HiddenDev:Impulsion(ennemie,zone,player,planet,index)
		print("Left")
		return
	elseif actionPlayer == "Right" then
		HiddenDev:Repuslion(ennemie,zone,player,planet)
		print("Right")
		return
		-- here its the charging action of the player, so when the player click to left start charging and with inpudended we remote "Left"  for start the attack
	elseif actionPlayer == "LeftCharging" then
		task.spawn(function()
			while actionPlayer == "LeftCharging" do
				-- here we creat a task.spawn to make the loop and make the zone grow and grow, so if you want to be more fast you can change the index
				task.wait(0.1)
				index += 0.4
				-- here we use tween for the size of the zone, 
				local twz = TweenService:Create(zone,TweenInfo.new(0.1),{Size = zone.Size + Vector3.new(index,index,index)})
				twz:Play()
				-- and here we wait the tween to finish
				twz.Completed:Wait()
				-- the player cannot charging more of 10 index, if he do that we stop the spell,for no bugs
				if index >= 10 then
					HiddenDev:Stopped(player,planet,zone)
					index = 0
				end
			end
			if actionPlayer == "Left" then
				HiddenDev:Impulsion(ennemie,zone,player,planet,index)
			end
		end)
	end
end

function HiddenDev:Stopped(player,planet,zone)
	-- Reset the cooldown and state in remove the player of the table
	spell_Cooldown[player.UserId] = nil
	spell_State[player.UserId] = nil
	Debris:AddItem(zone,0.01)
	-- check if the player have a orbite if yes then cancel for no bug (doublon etc)
	if 	planet.TablePoo.Orbite  then
		planet.TablePoo.Orbite:Disconnect()
	end
	-- and then we recreat the orbite for the player
	local humroot = player.Character:FindFirstChild("HumanoidRootPart")
	Orbite_Module:IdleChill(planet.TablePoo,humroot,"Left",0.5,0.1,1,1,1,1)
end

function HiddenDev:Repuslion(ennemie,zone,player,planet)
	local centreZone = zone.Position
	local radius = zone.Size.X/2
	local connect 
	local startime = tick()
	local action  = nil
	-- we check in the ennemie table if its a player or mob 
	for _, Ennemies in pairs(ennemie) do
		local humroot 
		if Ennemies:IsA("Player") then
			humroot = Ennemies.Character:FindFirstChild("HumanoidRootPart")
		else
			humroot = Ennemies:FindFirstChild("HumanoidRootPart")
		end		
		
		--here for all the player we use ApplyImpulse for creat a force for the player or mob, but we can use other methodes like  BodyVelocity or linearVelocity
		
		humroot:ApplyImpulse(humroot.CFrame.LookVector * -1000) 
	end
	-- here we call the client for activate the uis right action
	ActionSpellADvanced:FireClient(player,"Right+")
	
	-- then we heard the client for the action
	ActionSpellADvanced.OnServerEvent:Connect(function(player,actions)
		-- and we stock the action of the local in the serv for the next step
		action = actions
	end)
	
	-- here the serveu gonna wait the action of the player for 2 sec if the player dont do the action the spell is cancel
	while not action  do
		if tick() - startime >= 2 then
			--its creat a window for the player
			HiddenDev:Stopped(player,planet,zone)
			break
		end
		task.wait()
	end
	
	-- if the player do the action we continue the spell so (right+)
	if action then
		for i, Ennemies in ipairs(ennemie) do
			local humRoot
			-- same as before, so player or mob
			if Ennemies:IsA("Player") then
				humRoot = Ennemies.Character:FindFirstChild("HumanoidRootPart")
			else
				humRoot = Ennemies:FindFirstChild("HumanoidRootPart")
			end

			local nombrejoueurs = #ennemie
			local ecart = (2 * math.pi) / nombrejoueurs
			local angle = ecart * (i - 1)
			-- math be like, we take the angle of the player and the radius of the zone and we make a vector3 for the position of the player
			-- to place the player around the cercle of the zone
			-- this make a good effect
			
			local rayon = zone.Size.X / 2  
			-- for the rayon we take x of the zone and we divide by 2 because the size of the zone is the diameter
			local localPos = Vector3.new(
				math.cos(angle) * rayon,
				0,
				math.sin(angle) * rayon
			)

			
			local worldPos = (zone.CFrame * CFrame.new(localPos)).Position
			
			local cf = CFrame.lookAt(worldPos, zone.Position)

			local tw = TweenService:Create(
				humRoot,
				TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{ CFrame = cf }
			)
			-- we use tween service for the animation of the player or mob, more smooth, by adding the new CF for the player or mob
			tw:Play()
			tw.Completed:Wait()
			-- we wait surely the tween is finish
			-- here we make the explosion for a "effect of the impact" but we can add effect anims or other
			local explosion = Instance.new("Explosion")
			explosion.Position = worldPos
			explosion.BlastRadius = 100
			explosion.BlastPressure = 100000
			explosion.DestroyJointRadiusPercent = 0
			explosion.Parent = workspace
			humRoot.Parent:FindFirstChild("Humanoid"):TakeDamage(10)
			print("Explosion")
		end

		-- and here after the explosion we creat the knockback for the player or mob but its 
		for _, Ennemies in pairs(ennemie) do
			local humRoot 
			
			if Ennemies:IsA("Player") then
				humRoot = Ennemies.Character:FindFirstChild("HumanoidRootPart")
				humRoot:ApplyImpulse(humRoot.CFrame.LookVector * -1000) 
			else
				humRoot = Ennemies:FindFirstChild("HumanoidRootPart")
				humRoot:ApplyImpulse(humRoot.CFrame.LookVector * -1000) 
			end	
			local AP = Instance.new("AlignPosition")
			AP.Parent = humRoot
			AP.MaxForce = config.AstralCollapse.Sequence.Phase2.Params.Force 
			AP.Responsiveness = 100
			AP.Attachment0 = zone.Attachment
			AP.ForceRelativeTo = Enum.ActuatorRelativeTo.Attachment0

			-- here we can add effect, animation,damage by a fonction or module to the enenmy
			-- or call a another fonction for more detail 
			-- and all of that is configurable in the config module

			task.delay(config.AstralCollapse.Sequence.Phase2.Params.Duration,function()
				AP:Destroy()
				print("Est ca le detruit bien ")
				print(player)
				print(planet)
				print(zone)
				HiddenDev:Stopped(player,planet,zone)
			end)
		end
	end
	
	-- and we can add more and more and follow the sequence of the spell 
end
function HiddenDev:Impulsion(ennemie,zone,player,planet,index)
	local centreZone = zone.Position
	local radius = zone.Size.X/2
	local humRoot 
	
	for _, Ennemies in pairs(ennemie) do
		-- same as before player or mob and we stock the humanoidrootpart (hrp)
		if Ennemies:IsA("Player") then
			humRoot = Ennemies.Character:FindFirstChild("HumanoidRootPart")
		else
			humRoot = Ennemies:FindFirstChild("HumanoidRootPart")
			print(humRoot)
		end	
		-- we can add more stuff as exemple if the index > 10 then make a big effect explosion
		if index > 10 then
			local particule = game.ReplicatedStorage.Attachment:Clone()
			particule.Parent = zone
		end
		-- same here more we charge more we do 
		if index > 5 then
			local particule = game.ReplicatedStorage.Attachment:Clone()
			particule.Parent = zone
			particule.ParticleEmitter:Emit(100)
		end
		-- we applick knockback to the enemy and damage
		humRoot:ApplyImpulse(humRoot.CFrame.LookVector * -1000 * index) 
		local hum = humRoot.Parent:FindFirstChild("Humanoid")
		hum:TakeDamage(15 * index)
		
		-- here we can add effect, animation,damage by a fonction or module to the enenmy
		-- or call a another fonction for more detail 
		-- and all of that is configurable in the config module
		task.wait()
	end
	task.delay(config.AstralCollapse.Sequence.Phase2.Params.Duration,function()
		-- i use task.delay for the coroutine to not block the main thread because it can block the main script and make it crash so the task.delay run with the script in symbiosis
		humRoot.AssemblyLinearVelocity = Vector3.new(0,0,0)
		spell_Cooldown[player.UserId] = nil
		-- humroot assembly and spell cooldown we dont need to do it in the function but atleast you can see
		-- just for more detail, assemblylinear its the other way to move the player so when the knockback is finish we reset the assembly of the hrp 
		HiddenDev:Stopped(player,planet,zone)
	end)
end


function HiddenDev:StartSpell(player,mousetarget,planet,spawnpoint,mousepart)
	-- here its the main function how start and manipule the script and use fonction
	local istrue = HiddenDev:Resolver(player,mousetarget,mousepart)
	-- we check if the player can start the spell so , cooldwon good etc 
	if istrue then
		-- and the player is good we can start the spell
		HiddenDev:Applier(player,mousetarget,spawnpoint,planet,mousepart)
	end
end


return HiddenDev
