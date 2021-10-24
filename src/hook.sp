


public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip); // block weapon pickups
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);    
}

public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    damage = zombie_damage(attacker,victim, damage);
    return Plugin_Changed;
}


public Action OnPlayerDeath(Handle event, const String:name[], bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));

    zombie_death(attacker,victim);
}

public Action OnRoundStart(Handle event, const String:name[], bool dontBroadcast)
{
    zombie_start();
}

public Action OnRoundEnd(Handle event, const String:name[], bool dontBroadcast)
{
    zombie_end();
}

public Action OnWeaponEquip(int client, int weapon) 
{
    return zombie_weapon_equip(client,weapon);
}

public Action OnPlayerSpawn(Handle event, const String:name[], bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

    zombie_spawn(client);

}