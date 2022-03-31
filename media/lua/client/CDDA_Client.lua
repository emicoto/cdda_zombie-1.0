if isClient() then

local CDDAClientFunction={}
--从服务端接收丧尸种类
function CDDAClientFunction.SendZombieType(args)
    CDDA_ZombieList[args[1]]={args[2], args[3]}
end

local function CDDA_OnServerCommand(module, command, args)
    if module=="CDDA_Zombie" and CDDAClientFunction[command] then
        CDDAClientFunction[command](args)
    end
end

Events.OnServerCommand.Add(CDDA_OnServerCommand)

end