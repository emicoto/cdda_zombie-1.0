if isServer() then

local CDDAServerFunction={}
--客户端询问丧尸种类
function CDDAServerFunction.RequestZombieType(player, args)
    if CDDA_ZombieList[args[1]] then 
        sendServerCommand(player, "CDDA_Zombie", "SendZombieType", {args[1], CDDA_ZombieList[args[1]][1], CDDA_ZombieList[args[1]][2]})
    else--未定义过种类
        sendServerCommand(player, "CDDA_Zombie", "SendZombieType", {args[1], 0, 0})
    end
end
--从客户端接收丧尸种类数据
function CDDAServerFunction.SendZombieType(player, args)
    CDDA_ZombieList[args[1]]={args[2], args[3]}
end
--客户端询问丧尸升级
function CDDAServerFunction.UpdateZombieType(player, args)
    if CDDA_ZombieList[args[1]][2]==args[2] then--初次升级，更新服务端数据
        CDDA_ZombieList[args[1]] = {args[2], CDDA_GetEvoType(args[2])}
    end
    sendServerCommand(player, "CDDA_Zombie", "SendZombieType", {args[1], CDDA_ZombieList[args[1]][1], CDDA_ZombieList[args[1]][2]})
end
--客户端请求复活尸体
function CDDAServerFunction.ReanimateCorpse(player, args)
    local pSquare = player:getCurrentSquare()
    local square = player:getCell():getGridSquare(pSquare:getX()-args[1],pSquare:getY()-args[2],pSquare:getZ()-args[3])
    if square then
        local corpse = square:getDeadBody()
        if corpse then
            CDDA_Reanimate(corpse)
        end
    end
end

local function CDDA_OnClientCommand(module, command, player, args)
    if module=="CDDA_Zombie" and CDDAServerFunction[command] then
        CDDAServerFunction[command](player, args)
    end
end

Events.OnClientCommand.Add(CDDA_OnClientCommand)
end