
#define VERSION "0.0.1 - Violent Intent Zombie"


public Plugin myinfo = {
	name = "zm",
	author = "destoer",
	description = "zombie mode for css",
	version = VERSION,
	url = "https://github.com/destoer/zm"
};

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include "lib.inc"
#include "hook.sp"
#define ZM_PREFIX "\x04[NLG | Zombie]\x02"


// for no block!
Handle SetCollisionGroup;


bool round_over = false;

bool started = false;

int start_timer = 20;
#define ROUND_TIME 60
int countdown = ROUND_TIME;

// for zombies
float death_cords[64][3];

bool zombie[64];

bool zombie_win = false;

Handle g_ignore_round_win;

public OnPluginStart() 
{
	SetCollisionGroup = init_set_collision();
	
	g_ignore_round_win = FindConVar("mp_ignore_round_win_conditions");
	
	// no team bal
	Handle team_bal = FindConVar("mp_autoteambalance");
	SetConVarBool(team_bal, false);
	
	HookEvent("player_death", OnPlayerDeath,EventHookMode_Post);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);  
	HookEvent("player_spawn", OnPlayerSpawn);
	
	// TODO: implement zstuck & zspawn
		
		
	RegConsoleCmd("jointeam",join_command);
}


void disable_round_end()
{
	SetConVarBool(g_ignore_round_win, true);
}

void enable_round_end()
{
	SetConVarBool(g_ignore_round_win, false);
}



public OnMapStart()
{
	// for now just use the builtin in zombie model
	PrecacheModel("models/zombie/classic.mdl");
	PrecacheSound("npc/zombie/zombie_voice_idle1.wav");
	PrecacheSound("music/ravenholm_1.mp3");
	
	start_timer = 20;
}

public Action join_command(int client,args)
{
	// force to ct
	if(is_valid_client)
	{
	    CS_SwitchTeam(client, CS_TEAM_CT);
	
	    if(start_timer  > 0)
	    {
	        CS_RespawnPlayer(client);
	    }
	}
	
	return Plugin_Handled;
}


public create_knockback(int client, int attacker, float damage)
{	
	float attacker_ang[3];
	float attacker_pos[3]
	float client_pos[3]
	
	// attacker eye pos and angle
	GetClientEyePosition(attacker, attacker_pos);
	GetClientEyeAngles(attacker, attacker_ang);
	
	// get pos of where victim is from attacker "eyeline"
	// technically this will go until the nearest object from the attackers eyeline
	// to make handle dumb cases where a bullet hits multiple players
	// (so we wont get the victims actual pos but as we are normalizing the vector it doesent really matter)
	TR_TraceRayFilter(attacker_pos, attacker_ang, MASK_ALL, RayType_Infinite, trace_ignore_players);
	TR_GetEndPosition(client_pos);
	
	float push[3];
	
	// get position vector from attacker to victim
	MakeVectorFromPoints(attacker_pos, client_pos, push);
	
	// normalize the vector so it doesent care about how far away we are shooting from
	NormalizeVector(push, push);
	
	// scale it (may need balancing)
	float scale = damage * 3;
	ScaleVector(push, scale);
	
	// add the push to players velocity
	float vel[3];
	get_player_velocity(client, vel);
	
	float new_vel[3];
	AddVectors(vel, push, new_vel);
	
	set_player_velocity(client,new_vel);
}


void zombie_spawn(int client)
{
	// give p90 + deage on spawn
	if(is_valid_client(client) && !started)
	{
	    GivePlayerItem(client, "weapon_deagle");
	    GivePlayerItem(client, "weapon_p90");
	    GivePlayerItem(client, "item_assaultsuit"); 
	    GivePlayerItem(client, "weapon_hegrenade"); 
	}    
}

float zombie_damage(int attacker, int victim, float damage)
{
	if (!is_valid_client(attacker)) { return damage; }
	
	// block damage before start
	if(!started)
	{
		return 0.0;
	}
	
	// knockback is way to overkill on csgo
	if(GetClientTeam(victim) == CS_TEAM_T && GetEngineVersion() == Engine_CSS)
	{
	    create_knockback(victim, attacker, damage);
	} 
	
	if(GetClientTeam(victim) == CS_TEAM_CT)
	{
	    // knife damage
	    return 120.0;  
	}
	
	// for now no damage scaling
	else
	{
	    return damage;
	} 
}

Action zombie_weapon_equip(int client, int weapon)
{
	char weapon_string[32];
	GetEdictClassname(weapon, weapon_string, sizeof(weapon_string)); 
	
	// block zombie weapons
	if(GetClientTeam(client) == CS_TEAM_T && started)
	{
	    if(!StrEqual(weapon_string,"weapon_knife"))
	    {
	        return Plugin_Handled;
	    }
	}
	
	// restore reserve ammo
	// TODO: this is for pickup and not a switch
	// we need to hook this in a different place!
	else
	{
		set_reserve_ammo(client, weapon, 999);
	}
	
	return Plugin_Continue;	    
}

void zombie_death(int attacker,int victim)
{
	if(round_over)
	{
		return;
	}
		
	
	static int ct_count = 0;
	
	// test that first time hitting one ct
	int last_man;
	int cur_count = get_alive_team_count(CS_TEAM_CT, last_man);
	bool last_man_triggered  = (cur_count == 1) && (cur_count != ct_count)
	ct_count = cur_count;
	
	if(cur_count == 0 && !zombie_win)
	{
		zombie_win = true;
	    enable_round_end();
	    slay_all();
	    PrintToChatAll("%s Zombies win!",ZM_PREFIX);
	}
	
	else if(last_man_triggered)
	{
	    // LAST MAN STANDING
	    PrintCenterTextAll("%N IS LAST MAN STANDING!", last_man);
	    SetEntityHealth(last_man, 350);
	    int weapon = GetPlayerWeaponSlot(last_man, CS_SLOT_SECONDARY);
	    set_clip_ammo(last_man,weapon, 999);
	    weapon =  GetPlayerWeaponSlot(last_man, CS_SLOT_PRIMARY);
	    set_clip_ammo(last_man,weapon, 999);
	}
	
	
	
	
	int team = GetClientTeam(victim);
	// if victim is a ct -> become a zombie
	if(team == CS_TEAM_CT)
	{
	    float cords[3];
	    GetClientAbsOrigin(victim, cords);
	    
	    death_cords[victim] = cords;
	    death_cords[victim][2] -= 45.0; // account for player eyesight height
	    CreateTimer(0.5,new_zombie, victim)
	}
	
	else
	{
	    // just spawn them
	    CreateTimer(3.0, revive_zombie, victim);
	}
}

public Action revive_zombie(Handle timer, int client)
{
	CS_RespawnPlayer(client);
	CS_SwitchTeam(client, CS_TEAM_T);
	make_zombie(client);		
}


public Action new_zombie(Handle timer, int client)
{	
	CS_RespawnPlayer(client);
	TeleportEntity(client, death_cords[client], NULL_VECTOR, NULL_VECTOR);
	CS_SwitchTeam(client, CS_TEAM_T);
	make_zombie(client);
	EmitSoundToAll("npc/zombie/zombie_voice_idle1.wav");
}

Handle start_timer_handle =  INVALID_HANDLE;
Handle countdown_handle = INVALID_HANDLE;

bool empty_server()
{
	// no clients dont do anything
	return !GetClientCount(true);
}

void zombie_start()
{
	round_over = false;
	started = false;
	
	if(empty_server())
	{
	    return;
	}
	
	// swap everyone onto ct
	for(int i = 0; i < 64; i++)
	{
	    if(is_valid_client(i) && is_on_team(i))
	    {
            // reset stats
            set_client_speed(i, 1.0);
            SetEntityGravity(i, 1.0);

            CS_SwitchTeam(i, CS_TEAM_CT);
	    }
	}
	
	
	// setup 20 second timer to pick patient zero
	start_timer = 20;
	start_timer_handle = CreateTimer(1.0, MoreTimers);	
	
	// we need to test this works
	countdown = ROUND_TIME;
	disable_round_end();
	countdown_handle = CreateTimer(1.0,round_delay_tick);
}


public Action round_delay_tick(Handle Timer)
{
	if(countdown > 0)
	{
	    countdown -= 1;
	    CreateTimer(1.0,round_delay_tick);
	}
	
	// humans have survided the time limit
	else if(!zombie_win)
	{
	    PrintToChatAll("%s Humans win!",ZM_PREFIX);
	    enable_round_end();
	    round_over = true;
	    slay_all();
	    countdown_handle =  INVALID_HANDLE;
	}
}

// TODO: this is causing errors despite explicit handle checks?
void zombie_end()
{
	round_over = true;
	started = false;
	
	if(start_timer_handle != INVALID_HANDLE)
	{
	    KillTimer(start_timer_handle);
	    start_timer_handle =  INVALID_HANDLE;
	}
	
	if(countdown_handle != INVALID_HANDLE)
	{
	    KillTimer(countdown_handle);
	    countdown_handle =  INVALID_HANDLE;
	}
}

public Action MoreTimers(Handle timer)
{
	start_timer -= 1;
	PrintCenterTextAll("first infection in %d", start_timer); 
	if(start_timer > 0)
	{
		CreateTimer(1.0, MoreTimers);
	}
	
	else
	{
	    pick_patient_zero();
	    start_timer_handle =  INVALID_HANDLE;
	} 
}

int game_clients[64];

// on round start wait 20 seconds then pick a zombie
void pick_patient_zero()
{
	if(empty_server())
	{
	    return;
	}
	
	started = true;
	zombie_win = false;
	
	int player_count = 0;
	for(int i = 0; i < 64; i++)
	{
	    if(is_valid_client(i) && is_on_team(i))
	    {
			game_clients[player_count] = i;
			player_count++;
	    }
	    zombie[i] = false;
	}
	
	int client = game_clients[GetRandomInt( 0, player_count - 1 )];
	
	// this is the first player infected -> give them extra stuff
	CS_SwitchTeam(client, CS_TEAM_T);
	make_zombie(client);
	SetEntityHealth(client, 350 *  player_count);
	PrintCenterTextAll("%N is patient zero!", client);
	
	
	// incase anyone is still on T swap (cannot loop jam this incase of only one on other team)
	for(int i = 0; i < 64; i++)
	{
	    if(is_valid_client(i) && is_on_team(i) && !zombie[i])
	    {
			CS_SwitchTeam(i, CS_TEAM_CT);
		}
	}
	
	EmitSoundToAll("music/ravenholm_1.mp3");
}


public void set_zombie_speed(int client)
{
	set_client_speed(client, 1.2);
	SetEntityGravity(client, 0.4);
}

void make_zombie(int client)
{
	if(is_valid_client(client) && is_on_team(client))
	{
	    strip_all_weapons(client);
	    set_zombie_speed(client)
	    SetEntityHealth(client, 1500);
	    GivePlayerItem(client, "weapon_knife");
	
	    unblock_client(client,SetCollisionGroup);
	    set_zombie_model(client);
	    zombie[client] = true;
	}    
}


void set_zombie_model(int client)
{
	if(is_valid_client(client) && is_on_team(client))
	{
		SetEntityModel(client, "models/zombie/classic.mdl");     
	}
}