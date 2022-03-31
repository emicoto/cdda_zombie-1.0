Events.EveryDays.Add(CDDA_Days)
Events.OnZombieDead.Add(CDDA_OnZombieDie)

if not isServer() then
    Events.OnWeaponHitCharacter.Add(CDDA_FuncOnHit)	
    --Events.OnCharacterCollide.Add(CDDA_FuncOnCollide)
    Events.OnZombieUpdate.Add(CDDA_ZombieUpdate)
    Events.EveryTenMinutes.Add(CDDA_FuncOnMin)
    Events.OnPlayerUpdate.Add(CDDA_GetZombieOnPlayerMouse)
    Events.OnLoad.Add(CDDA_LoadSandboxDefaults)
    Events.OnSave.Add(CDDA_SaveSandboxDefaults)
    Events.OnTick.Add(CDDA_ShowZombieType)
else
    Events.OnServerStarted.Add(CDDA_LoadSandboxDefaults)
    Events.OnServerStartSaving.Add(CDDA_SaveSandboxDefaults)
end

if not isClient() then
    Events.OnContainerUpdate.Add(CDDA_UpdateCorpse)
    Events.OnPlayerDeath.Add(CDDA_OnPlayerDeath)
end