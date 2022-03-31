CDDA_ZombieFunction = {}

function PrintTable(table , level)
  local key = ""
  level = level or 1
  local indent = ""
  for i = 1, level do
    indent = indent.."  "
  end

  if key ~= "" then
    print(indent..key.." ".."=".." ".."{")
  else
    print(indent .. "{")
  end

  key = ""
  for k,v in pairs(table) do
     if type(v) == "table" then
        key = k
        PrintTable(v, level + 1)
     else
        local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
      print(content)  
      end
  end
  print(indent .. "}")

end

function CDDA_Totalchance()
	local totalchance = 0
	for i=1, #CDDA_Zombies do
		totalchance=cdda_totalchance+CDDA_Zombies[i].chance
	end
	return totalchance
end

function CDDA_ZombieInit()
	CDDA_FuncPerMin = {}
	CDDA_FuncCollide = {}
	CDDA_ShowZombieName = {}
	CDDA_ZombieList = {}
	CDDA_PlayerCorpse = {}
	CDDA_SetZombies()
	cdda_totalchance = 0
	CDDA_OutfitZ = {}
	for i=1,#CDDA_Zombies do
		cdda_totalchance=cdda_totalchance+CDDA_Zombies[i].chance
		if CDDA_Zombies[i].outfit then
			for j=1,#CDDA_Zombies[i].outfit do
				CDDA_OutfitZ[CDDA_Zombies[i].outfit[j]] = i
			end
		end
	end
	EvoFactor = getSandboxOptions():getOptionByName("CDDAZombies.EvoFactor"):getValue()

	if EvoFactor > 0 then
		local worldAge =  getWorld():getWorldAgeDays() + 0.3;
		local sandMonthsAfter = getSandboxOptions():getTimeSinceApo() - 1;
		local actualSpawnAgeDay = worldAge - (sandMonthsAfter * 30);
		worldAge = math.max(0.0, actualSpawnAgeDay);
		CDDA_ZombieEvo(worldAge)
	end

end

function CDDA_checkTime(ztype)
	local gTime = getGameTime()
	local hour = gTime:getTimeOfDay()
	local startTime = 0
	local endTime = 24

	if(CDDA_Zombies[ztype].starthour)then
		startTime = CDDA_Zombies[ztype].starthour
		endTime = CDDA_Zombies[ztype].endhour

		-- 在时间带内并生成指定的特殊丧尸
		if(hour >= startTime and hour < endTime) or ((hour >= startTime or hour<endTime) and startTime>endTime) then
			return ztype
		else
		-- 非时间带内超低概率生成指定的特殊丧尸，否则从低等丧尸中选取
			if(ZombRand(1000) < 10) then
				return ztype
			else
				local list = {2,5,6,11,14,15,16,17,18,20}
				local id = list[ZombRand(#list)+1]

				if CDDA_checkRate(id,true) then 
					return id
				else
					return 20
				end
			end
		end
	end

	return ztype
end

function CDDA_checkRate(id,double)
	local random = ZombRand(cdda_totalchance + 1)
	local rate = CDDA_Zombies[id].chance

	if double then
		rate = rate*2
	end

	if random <= rate then return true end

	return false
end

--丧尸进化
function CDDA_ZombieEvo(t)
	if t == nil then
		t = 1
	end

	for i=1,#CDDA_Zombies do
		if CDDA_Zombies[i].evo then
			for j,k in pairs(CDDA_Zombies[i].evo) do
				if CDDA_Zombies[i].chance > 0 and CDDA_Zombies[k].spawn then
					local efactor = EvoFactor * CDDA_Zombies[i].chance * CDDA_Zombies[k].chance / (300*cdda_totalchance)
					efactor = math.floor(efactor*1000+0.5)/1000
					efactor = math.min(EvoFactor, efactor) * t
					CDDA_Zombies[i].chance = CDDA_Zombies[i].chance - efactor
					CDDA_Zombies[k].chance = CDDA_Zombies[k].chance + efactor
				end
			end
		end
	end
end

function CDDA_Days()
	if EvoFactor > 0 then
	--	DaysSurvived = DaysSurvived + 1
	--	if DaysSurvived>EvoFactor then
	--		DaysSurvived = DaysSurvived - EvoFactor
			CDDA_ZombieEvo()
	--	end
	end
end

function caldistance(zombie,player)
	return (math.abs(zombie:getX()-player:getX())^2 + math.abs(zombie:getY()-player:getY())^2)^0.5
end

function CDDA_GetZombieID(zombie)
	local id
	if isClient() or isServer() then
		id = zombie:getOnlineID()
	else
		id = zombie:getID()
	end
	return id
end

function CDDA_OnZombieDie(zombie)
	local ZID = CDDA_GetZombieID(zombie)
	CDDA_ZombieList[ZID] = nil
	if not isServer() then
		CDDA_FuncPerMin[ZID] = nil
		CDDA_FuncCollide[ZID] = nil
		CDDA_ShowZombieName[ZID] = nil
		if zombie:getModData().userName then
			zombie:getModData().userName:Clear()
		end
	end
end

--获取丧尸的进化类型
function CDDA_GetEvoType(ZType)
	local evo = ZType
	if CDDA_Zombies[ZType].evo then
		evo = CDDA_Zombies[ZType].evo[ZombRand(#CDDA_Zombies[ZType].evo)+1]
	end
	return evo
end

--将有KeyRing的尸体标记为玩家尸体
function CDDA_UpdateCorpse(corpse)
	if corpse and instanceof(corpse, "IsoDeadBody") then
		if corpse:getContainer():contains("Base.KeyRing") then
			CDDA_PlayerCorpse[CDDA_GetZombieID(corpse)]=true
		end
	end
end

--复活尸体
function CDDA_Reanimate(corpse)
	--保证复活的玩家尸体上有KeyRing
	if CDDA_PlayerCorpse[CDDA_GetZombieID(corpse)] then
		if not corpse:getContainer():contains("Base.KeyRing") then
			corpse:getContainer():AddItem("Base.KeyRing")
		end
		CDDA_PlayerCorpse[CDDA_GetZombieID(corpse)]=nil
	end
	corpse:reanimate()
end

--给死去玩家添加KeyRing
function CDDA_OnPlayerDeath(player)
	if not player:getInventory():contains("Base.KeyRing") then
		player:getInventory():AddItem("Base.KeyRing")
	end
end
	
--获取丧尸类别
function CDDA_GetZombieType(zombie)
    local ZType = 0
	local outfit = zombie:getOutfitName()
--特定种类丧尸直接设置相应类别
	if zombie:getInventory():contains("Base.KeyRing") then
	--如果是玩家复活的尸体则强制为幸存者丧尸
		ZType = 11
	elseif outfit and CDDA_OutfitZ and CDDA_OutfitZ[outfit] then
        ZType = CDDA_OutfitZ[outfit]
	else
--随机丧尸类别
		for k, v in pairs(CDDA_Zombies) do
			local breakcheck = false
			if CDDA_checkRate(k) then
				breakcheck = true
			end
            if not CDDA_Zombies[k].spawn and not CDDA_Sandbox then
                breakcheck = false
            end
            if zombie:isSkeleton() and breakcheck then
				if CDDA_checkRate(4) then 
					ZType = 4 
				else 
					ZType = 2 
				end

            elseif breakcheck then 
				ZType = k
				break 
			end
		end
		if not ZType or ZType == 0 then
			ZType = 20
		end
    end
	ZType = CDDA_checkTime(ZType)	
    return ZType
end

--设置丧尸属性
function CDDA_SetZombieType(zombie,ZType)

    zombie:getModData().CDDA_ZType = ZType

	local HP_Multi = 0
	if zombie:getClothingItem_Head() then
		HP_Multi = HP_Multi + zombie:getClothingItem_Head():getScratchDefense()
	end
	if zombie:getClothingItem_Torso() then
		HP_Multi = HP_Multi + zombie:getClothingItem_Torso():getScratchDefense()
	end
	HP_Multi = 1 + HP_Multi/100
	local data = CDDA_Zombies[ZType]
	zombie:setHealth(data.HP*HP_Multi)
	if data.walktype ~= 4 then
		if CDDA_Sandbox then
			getSandboxOptions():set("ZombieLore.Speed", data.walktype)
		end
		zombie:setCanWalk(true)
		zombie:setFallOnFront(false)
	else
		zombie:setCanWalk(false)
		zombie:setFallOnFront(true)
		if not zombie:isCrawling() then
			zombie:toggleCrawling()
		end
	end
	if CDDA_Sandbox then
		getSandboxOptions():set("ZombieLore.Strength",data.strength)
		--getSandboxOptions():set("ZombieLore.Toughness",data.toughness)
		getSandboxOptions():set("ZombieLore.Cognition",data.cognition)
		--getSandboxOptions():set("ZombieLore.Transmission",data.transmission)
		--getSandboxOptions():set("ZombieLore.Memory",data.memory)
		--getSandboxOptions():set("ZombieLore.Sight",data.sight)
		--getSandboxOptions():set("ZombieLore.Hearing",data.hearing)
		zombie:makeInactive(true);
		zombie:makeInactive(false);
		--zombie:setNoTeeth(data.noteeth)
		--zombie:DoZombieStats()
	end
	if data.skeleton and not zombie:isSkeleton() then
			zombie:setSkeleton(true)
			zombie:getHumanVisual():setHairModel("")
			zombie:getHumanVisual():setBeardModel("")
	end
	if ZType==17 then
		zombie:getHumanVisual():setBeardModel("")
	end
	if data.funcpermin then
		CDDA_FuncPerMin[CDDA_GetZombieID(zombie)] = {zombie, data.funcpermin}
	end
	if data.funccollide then
		CDDA_FuncCollide[CDDA_GetZombieID(zombie)] = data.funccollide
	end
	zombie:getModData().userName = TextDrawObject.new()
	zombie:getModData().userName:setDefaultColors(data.color[1]/255, data.color[2]/255, data.color[3]/255,1)
	zombie:getModData().userName:setOutlineColors(data.outline[1]/255, data.outline[2]/255, data.outline[3]/255,1)
	zombie:getModData().showName = 100
	zombie:getModData().update = 1000
end


--更新丧尸属性
function CDDA_UpdateZombie(zombie,ZType)

	if zombie:getModData().CDDA_ZType ~= ZType then
		zombie:getModData().CDDA_ZType = ZType
	end
	
	local data = CDDA_Zombies[ZType]

	if data.walktype ~= 4 then
		if CDDA_Sandbox then
			getSandboxOptions():set("ZombieLore.Speed", data.walktype)
		end
		zombie:setCanWalk(true)
	elseif zombie:isCanWalk() then
		zombie:setCanWalk(false)
		zombie:setFallOnFront(true)
		if not zombie:isCrawling() then
			zombie:toggleCrawling()
		end
	end
	if CDDA_Sandbox then
		getSandboxOptions():set("ZombieLore.Strength",data.strength)
		--getSandboxOptions():set("ZombieLore.Toughness",data.toughness)
		getSandboxOptions():set("ZombieLore.Cognition",data.cognition)
		--getSandboxOptions():set("ZombieLore.Transmission",data.transmission)
		--getSandboxOptions():set("ZombieLore.Memory",data.memory)
		--getSandboxOptions():set("ZombieLore.Sight",data.sight)
		--getSandboxOptions():set("ZombieLore.Hearing",data.hearing)
		zombie:makeInactive(true);
		zombie:makeInactive(false);
		--zombie:DoZombieStats()
		--zombie:setNoTeeth(data.noteeth)
	end
	if data.skeleton and not zombie:isSkeleton() then
		zombie:setSkeleton(true)
		zombie:getHumanVisual():setHairModel("")
		zombie:getHumanVisual():setBeardModel("")
	end
end

--丧尸属性刷新
function CDDA_ZombieUpdate(zombie)
	local ZType = zombie:getModData().CDDA_ZType
	if ZType and ZType > 0 then  
		ZType = CDDA_checkTime(ZType)

		if(ZType ~= zombie:getModData().CDDA_ZType)then 
			zombie:getModData().CDDA_ZType = ZType
			zombie:getModData().update = 0
		end

	end

	local ZID = zombie:getOnlineID()
	if ZType == nil then
		local outfit = zombie:getOutfitName()
		if outfit or zombie:isReanimatedPlayer() then
			if isClient() then--客户端询问丧尸种类
				CDDA_ZombieList[ZID] = {}
				zombie:getModData().CDDA_ZType = 0
				sendClientCommand("CDDA_Zombie", "RequestZombieType", {ZID})
			else--单机直接设置种类
				CDDA_SetZombieType(zombie, CDDA_GetZombieType(zombie))
			end
		end
	elseif ZType == 0 and CDDA_ZombieList[ZID] then--客户端等待种类被定义
		if CDDA_ZombieList[ZID][1] then
			if CDDA_ZombieList[ZID][1]~=0 then
				CDDA_SetZombieType(zombie, CDDA_ZombieList[ZID][1])
			else--客户端自行定义种类并将结果告知服务端
				local zType = CDDA_GetZombieType(zombie)
				CDDA_SetZombieType(zombie, zType)
				CDDA_ZombieList[ZID] = {zType, CDDA_GetEvoType(zType)}
				sendClientCommand("CDDA_Zombie", "SendZombieType", {ZID, zType, CDDA_ZombieList[ZID][2]})
			end
		end
	elseif CDDA_Zombies[ZType] then
		--设置丧尸能否被推倒
		if CDDA_Zombies[ZType].keepstand then
			zombie:setKnockedDown(false)
		end
		if zombie:getModData().update == 0 then
			zombie:getModData().update = 1000
			CDDA_UpdateZombie(zombie,ZType)
		else
			zombie:getModData().update = zombie:getModData().update - 1
		end
		--客户端更新升级后的丧尸种类
		if isClient() and CDDA_ZombieList[ZID] and CDDA_ZombieList[ZID][1] then
			if ZType~=CDDA_ZombieList[ZID][1] then
				CDDA_UpdateZombie(zombie,CDDA_ZombieList[ZID][1])
			else
				sendClientCommand("CDDA_Zombie", "RequestZombieType", {ZID})
			end
		end
		--运行特殊丧尸代码
		if CDDA_Zombies[ZType].functions then
			CDDA_ZombieFunction[CDDA_Zombies[ZType].functions](zombie)
		end
	end
end

--丧尸推开玩家
function CDDA_ZombieFunction.Push(zombie)
	if zombie:isAttacking() then
		local player = zombie:getTarget()
		if player and player:isCharacter() then
			player:attackFromWindowsLunge(zombie)
		end
	end
end

--丧尸免疫火焰
function CDDA_ZombieFunction.EndFire(zombie)
	if zombie:isOnFire() then
		zombie:setOnFire(false)
	end
end

--攻击儿童丧尸加忧郁
function CDDA_ZombieFunction.Unhappy(player, zombie, handWeapon, damage)
	if player and player:isAlive() then
		local bodyDamage = player:getBodyDamage()
		bodyDamage:setUnhappynessLevel(math.min(100,bodyDamage:getUnhappynessLevel()+math.min(10,damage)))
	end
end

function CDDA_FuncOnHit(player, zombie, handWeapon, damage)
	if zombie:isZombie() then
		local ZType = zombie:getModData().CDDA_ZType
		if ZType then
			if CDDA_Zombies[ZType].funconhit then
				CDDA_ZombieFunction[CDDA_Zombies[ZType].funconhit](player, zombie, handWeapon, damage)
			end
		end
	end
end

--丧尸尖叫
function ZombieFollowScream(screamer)
	local player = screamer:getTarget()
	local zombies = player:getCell():getZombieList()
	for i=1,zombies:size() do
		local zombie = zombies:get(i-1)
		if not zombie:getTarget() then
			if caldistance(screamer,zombie)<20 or (caldistance(screamer,zombie)<40 and zombie:getModData().CDDA_ZType == 12) then
				zombie:pathToCharacter(screamer)
			end
		end
	end
end

function CDDA_ZombieFunction.Scream(zombie)
	local player = zombie:getTarget()
	if player then
		zombie:getModData().CDDA_Scream = zombie:getModData().CDDA_Scream or 0
		if zombie:getModData().CDDA_Scream==0 then
			zombie:playSound("screamer"..tostring(ZombRand(2)+1))
			ZombieFollowScream(zombie)
			zombie:getModData().CDDA_Scream = 5
		else
			zombie:getModData().CDDA_Scream = zombie:getModData().CDDA_Scream - 1
		end
	end
end

--主宰丧尸升级附近丧尸
function CDDA_ZombieFunction.Upgrade(zombie)
	local player = zombie:getTarget()
		if player then
		local square = zombie:getCurrentSquare()
		if not instanceof(square, "IsoGridSquare") then return end -- 会有不返回IsoGridSquare的情况，原因不明
		local squares = {square,square:getE(),square:getS(),square:getW(),square:getN()}
		for i=1,5 do
			if instanceof(squares[i], "IsoGridSquare") then
				local zombie2 = squares[i]:getZombie() --似乎会在联机时导致超同
				if zombie2 and zombie2:isZombie() then
					local ZType = zombie2:getModData().CDDA_ZType
					if ZType and CDDA_Zombies[ZType].evo then
						if isClient() then
							local zID = zombie2:getOnlineID()
							if CDDA_ZombieList[zID] then
								local zType = CDDA_ZombieList[zID][2]
								if zType~=0 and ZType~=zType then
									sendClientCommand("CDDA_Zombie", "UpdateZombieType", {zID, zType})
									break
								end
							end
						else
							CDDA_UpdateZombie(zombie2, CDDA_GetEvoType(ZType))
						end
					end
				end
			end
		end
	end
end

--巫妖丧尸复活附近尸体
function CDDA_ZombieFunction.Reanim(zombie)
	local square = zombie:getCurrentSquare()
	if not instanceof(square, "IsoGridSquare") then return end -- 会有不返回IsoGridSquare的情况，原因不明
	local squares = {square,square:getE(),square:getS(),square:getW(),square:getN()}
	for i=1,5 do
		if instanceof(squares[i], "IsoGridSquare") then
			local corpse = squares[i]:getDeadBody() --似乎会在联机时导致超同
			if corpse and not corpse:isSkeleton() then
				if isClient() then
					local pSquare=getPlayer():getCurrentSquare()
					sendClientCommand("CDDA_Zombie", "ReanimateCorpse", {pSquare:getX()-squares[i]:getX(),pSquare:getY()-squares[i]:getY(),pSquare:getZ()-squares[i]:getZ()})
				else
					CDDA_Reanimate(corpse)
					break
				end
			end
		end
	end
end
	
function CDDA_FuncOnMin()
	for id, zombie in pairs(CDDA_FuncPerMin) do
		if zombie[1]:isAlive() then
			CDDA_ZombieFunction[zombie[2]](zombie[1])
		else
			CDDA_FuncPerMin[id] = nil
		end
	end
end

function CDDA_FuncOnCollide(cha1, cha2)
	local player, zombie=cha1, cha2
	if cha1:isZombieAttacking(cha2) then player, zombie=cha2, cha1 end
	for id, funcs in pairs(CDDA_FuncCollide) do
		if id==CDDA_GetZombieID(zombie) then
			CDDA_ZombieFunction[funcs](player,zombie)
		end
	end
end

--肉钩丧尸抓取玩家
function CDDA_ZombieFunction.Grab(player,zombie)
	player:setSlowFactor(0.7)
    player:setSlowTimer(5)
end

function CDDA_ZombieFunction.GrabOnAttack(zombie)
	if zombie:isAttacking() then
		local player = zombie:getTarget()
		if player and player:isCharacter() then
			player:setSlowFactor(0.7)
			player:setSlowTimer(5)
		end
	end
end

--获取玩家鼠标指向的丧尸
function CDDA_GetZombieOnPlayerMouse(player)
	if CDDA_NameTag and player:isLocalPlayer() and player:isAiming() then
		local playerX = player:getX()
		local playerY = player:getY()
		local playerZ = player:getZ()
		local mouseX, mouseY = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), 0);
		local targetMouseX = mouseX+1.5;
		local targetMouseY = mouseY+1.5;
		local direction = (math.atan2(targetMouseY-playerY, targetMouseX-playerX));
		
		local feetDirection = player:getDir():toAngle();
		if feetDirection < 2 then
			feetDirection = -(feetDirection+(math.pi*0.5))
		else
			feetDirection = (math.pi*2)-(feetDirection+(math.pi*0.5))
		end
		if math.cos(direction - feetDirection) < math.cos(67.5) then
			if math.sin(direction - feetDirection) < 0 then
				direction = feetDirection - (math.pi/4)
			else
				direction = feetDirection + (math.pi/4)
			end
		end --Avoids an aiming angle pointing behind the person
		
		local aimingAngle = 10
		local aimingDistance = 50
		
		local playerOffsetX = playerX - math.floor(playerX);
		local playerOffsetY = playerY - math.floor(playerY);
		
		local mWorldZ = playerZ;
		
		--playerZ = player:getZ();
		
		local cell = getWorld():getCell();
		local square = cell:getGridSquare(math.floor(targetMouseX), math.floor(targetMouseY), playerZ);
		if playerZ > 0 then
			for i=math.floor(playerZ), 1, -1 do
				square = cell:getGridSquare(math.floor(mouseX+1.5)+(i*3), math.floor(mouseY+1.5)+(i*3), i);
				if square and square:isSolidFloor() then
					targetMouseX = mouseX+1.5+i;
					targetMouseY = mouseY+1.5+i;
					break
				end
			end
		end
		if square then
			local movingObjects = square:getMovingObjects();
			if (movingObjects ~= nil) then
				for ii=0, movingObjects:size()-1 do
					local zombie = movingObjects:get(ii)
					if string.find(tostring(zombie),"IsoFallingClothing") == nil then
						if zombie:isZombie() then
							if player:CanSee(zombie) then
								CDDA_ShowZombieName[CDDA_GetZombieID(zombie)] = {zombie, 255}
							end
						end
					end
				end
			end
		end
	end
end

--显示丧尸种类
function CDDA_ShowZombieType()
	for zid, data in pairs(CDDA_ShowZombieName) do
		local zombie,interval,player = data[1],data[2],getPlayer()
		local ZType = zombie:getModData().CDDA_ZType

		if interval>0 then
			CDDA_ShowZombieName[zid][2] = CDDA_ShowZombieName[zid][2] - 5
			if zombie:isAlive() and player:CanSee(zombie) then
				if CDDA_Zombies[ZType] then
					zombie:getModData().userName:setDefaultColors(CDDA_Zombies[ZType].color[1]/255,CDDA_Zombies[ZType].color[2]/255,CDDA_Zombies[ZType].color[3]/255,interval/255)
					zombie:getModData().userName:setOutlineColors(CDDA_Zombies[ZType].outline[1]/255,CDDA_Zombies[ZType].outline[2]/255,CDDA_Zombies[ZType].outline[3]/255,interval/255)
					zombie:getModData().userName:ReadString(UIFont.Small, getText(CDDA_Zombies[ZType].name), -1)
					local sx = IsoUtils.XToScreen(zombie:getX(), zombie:getY(), zombie:getZ(), 0);
					local sy = IsoUtils.YToScreen(zombie:getX(), zombie:getY(), zombie:getZ(), 0);
					sx = sx - IsoCamera.getOffX() - zombie:getOffsetX();
					sy = sy - IsoCamera.getOffY() - zombie:getOffsetY();
					sy = sy - 128
					sx = sx / getCore():getZoom(0)
					sy = sy / getCore():getZoom(0)
					sy = sy - zombie:getModData().userName:getHeight()
					zombie:getModData().userName:AddBatchedDraw(sx, sy, true)
				end
			else
				CDDA_ShowZombieName[zid] = nil
			end
		end
	end
end



