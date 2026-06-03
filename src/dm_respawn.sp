/**
 * Simple Deathmatch Respawn + Spawn Protection (CS:S)
 * ---------------------------------------------------
 * Respawns players a short time after they die (continuous team deathmatch)
 * and grants reliable spawn protection via SDKHooks (blocks ALL incoming
 * damage during the protection window - cannot be overridden by game logic).
 * Does NOT strip or give weapons (GunGame:SM handles that), so no conflict.
 *
 * Cvars (cfg/sourcemod/dm_respawn.cfg):
 *   sm_dm_enabled            1     - enable respawning
 *   sm_dm_respawntime        1.0   - seconds after death before respawn
 *   sm_dm_protecttime        3.0   - seconds of spawn protection (0 = off)
 *   sm_dm_protect_breakonfire 1    - end protection as soon as the player shoots
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvEnabled;
ConVar g_cvRespawnTime;
ConVar g_cvProtectTime;
ConVar g_cvBreakOnFire;

bool g_bProtected[MAXPLAYERS + 1];
int  g_iSpawnTries[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "Simple DM Respawn",
    author      = "Claude",
    description = "Instant respawn + reliable SDKHooks spawn protection for GunGame deathmatch",
    version     = "2.0.0",
    url         = ""
};

public void OnPluginStart()
{
    g_cvEnabled     = CreateConVar("sm_dm_enabled",     "1",   "Enable deathmatch respawning (1/0).", _, true, 0.0, true, 1.0);
    g_cvRespawnTime = CreateConVar("sm_dm_respawntime", "1.0", "Seconds after death before a player respawns.", _, true, 0.0, true, 30.0);
    g_cvProtectTime = CreateConVar("sm_dm_protecttime", "3.0", "Seconds of spawn protection after respawn. 0 = off.", _, true, 0.0, true, 30.0);
    g_cvBreakOnFire = CreateConVar("sm_dm_protect_breakonfire", "1", "End spawn protection as soon as the player attacks (1/0).", _, true, 0.0, true, 1.0);

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("weapon_fire",  Event_WeaponFire,  EventHookMode_Post);
    HookEvent("player_team",  Event_PlayerTeam,  EventHookMode_Post);

    for (int i = 1; i <= MaxClients; i++)
        if (IsClientInGame(i))
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);

    AutoExecConfig(true, "dm_respawn");
}

public void OnClientPutInServer(int client)
{
    g_bProtected[client] = false;
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    g_bProtected[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients)
        return;

    g_bProtected[client] = false;

    if (!g_cvEnabled.BoolValue)
        return;

    CreateTimer(g_cvRespawnTime.FloatValue, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Respawn(Handle timer, int userid)
{
    if (!g_cvEnabled.BoolValue)
        return Plugin_Stop;

    int client = GetClientOfUserId(userid);
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Stop;

    int team = GetClientTeam(client);
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return Plugin_Stop;

    if (IsPlayerAlive(client))
        return Plugin_Stop;

    CS_RespawnPlayer(client);
    return Plugin_Stop;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    if (event.GetBool("disconnect"))
        return;

    int team = event.GetInt("team");
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients)
        return;

    // A player who just joined a team has not spawned yet (rounds never
    // restart in this deathmatch). But we must NOT spawn before they have
    // finished class/model selection - selecting a model after spawning
    // would kill them. Wait until a class is chosen, then spawn.
    g_iSpawnTries[client] = 0;
    CreateTimer(0.5, Timer_JoinSpawn, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_JoinSpawn(Handle timer, int userid)
{
    if (!g_cvEnabled.BoolValue)
        return Plugin_Stop;

    int client = GetClientOfUserId(userid);
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Stop;

    int team = GetClientTeam(client);
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return Plugin_Stop;

    if (IsPlayerAlive(client))
        return Plugin_Stop;   // already spawned, nothing to do

    g_iSpawnTries[client]++;

    // Has the player picked a class/model yet? (m_iClass != 0)
    bool classChosen = true;
    if (HasEntProp(client, Prop_Send, "m_iClass"))
        classChosen = (GetEntProp(client, Prop_Send, "m_iClass") != 0);

    // Spawn once a class is chosen, or after ~12s as a safety net.
    if (classChosen || g_iSpawnTries[client] >= 24)
    {
        CS_RespawnPlayer(client);
        return Plugin_Stop;
    }

    return Plugin_Continue;   // keep waiting
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    float protect = g_cvProtectTime.FloatValue;
    if (protect <= 0.0)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return;

    int team = GetClientTeam(client);
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return;

    if (!IsPlayerAlive(client))
        return;

    g_bProtected[client] = true;

    // Visual tint so everyone can see who is protected.
    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
    SetEntityRenderColor(client, 0, 128, 255, 175);

    CreateTimer(protect, Timer_EndProtect, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_EndProtect(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client < 1 || client > MaxClients)
        return Plugin_Stop;

    EndProtection(client);
    return Plugin_Stop;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvBreakOnFire.BoolValue)
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients)
        return;

    if (g_bProtected[client])
        EndProtection(client);
}

void EndProtection(int client)
{
    g_bProtected[client] = false;

    if (IsClientInGame(client))
    {
        SetEntityRenderMode(client, RENDER_NORMAL);
        SetEntityRenderColor(client, 255, 255, 255, 255);
    }
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (victim >= 1 && victim <= MaxClients && g_bProtected[victim])
        return Plugin_Handled;   // block all damage while protected

    return Plugin_Continue;
}
