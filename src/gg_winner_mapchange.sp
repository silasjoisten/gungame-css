/**
 * GunGame Winner -> Announce + Pause + Map Change
 * -----------------------------------------------
 * When GunGame:SM declares a winner this plugin:
 *   1. shows a UI message (chat + hint box) with the winner's name,
 *   2. freezes everyone for a couple of seconds (dramatic pause),
 *   3. after a delay, changes to the map that was chosen in the vote
 *      (sm_nextmap, set by mapchooser) - GunGame itself never does this.
 *
 * Cvars (cfg/sourcemod/gg_winner_mapchange.cfg):
 *   sm_gg_winchange_enabled  1    - 1 = announce + change map on win
 *   sm_gg_winchange_delay    8.0  - seconds after the win before changing map
 *   sm_gg_winfreeze          2.0  - seconds to freeze everyone on win (0 = off)
 *
 * Admin command:
 *   sm_gg_changenow              - force the next-map change now (flag: changemap)
 */

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#include <gungame>

new Handle:g_cvEnabled = INVALID_HANDLE;
new Handle:g_cvDelay   = INVALID_HANDLE;
new Handle:g_cvFreeze  = INVALID_HANDLE;
new bool:g_bChanging   = false;

public Plugin:myinfo =
{
    name        = "GunGame Winner MapChange",
    author      = "Claude",
    description = "Winner UI message + short pause, then change to the voted next map",
    version     = "2.0.0",
    url         = ""
};

public OnPluginStart()
{
    g_cvEnabled = CreateConVar("sm_gg_winchange_enabled", "1", "Announce winner + change map on a GunGame win (1/0).", _, true, 0.0, true, 1.0);
    g_cvDelay   = CreateConVar("sm_gg_winchange_delay", "8.0", "Seconds to wait after the win before changing map.", _, true, 0.0, true, 60.0);
    g_cvFreeze  = CreateConVar("sm_gg_winfreeze", "2.0", "Seconds to freeze everyone when a winner is declared (0 = off).", _, true, 0.0, true, 15.0);

    RegAdminCmd("sm_gg_changenow", Cmd_ChangeNow, ADMFLAG_CHANGEMAP, "Force the change to the next map immediately.");

    AutoExecConfig(true, "gg_winner_mapchange");
}

public OnMapStart()
{
    g_bChanging = false;
}

/* Fired by GunGame:SM when a player wins the game. */
public GG_OnWinner(client, const String:Weapon[], victim)
{
    if (!GetConVarBool(g_cvEnabled))
        return;

    if (g_bChanging)
        return;
    g_bChanging = true;

    // --- Winner name ---
    decl String:wname[MAX_NAME_LENGTH];
    strcopy(wname, sizeof(wname), "The winner");
    if (client >= 1 && client <= MaxClients && IsClientInGame(client))
        GetClientName(client, wname, sizeof(wname));

    AnnounceWinner(wname);

    // --- Dramatic pause: freeze everyone ---
    new Float:freezeTime = GetConVarFloat(g_cvFreeze);
    if (freezeTime > 0.0)
    {
        FreezeAllPlayers(true);
        CreateTimer(freezeTime, Timer_Unfreeze, _, TIMER_FLAG_NO_MAPCHANGE);
    }

    // --- Change to the voted next map after the delay ---
    CreateTimer(GetConVarFloat(g_cvDelay), Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
}

AnnounceWinner(const String:name[])
{
    // Coloured chat banner
    PrintToChatAll("\x01\x04**********************************");
    PrintToChatAll("\x04>> \x03%s \x04hat GunGame gewonnen! \x07", name);
    PrintToChatAll("\x01\x04**********************************");

    // Big hint box in the centre of the screen for everyone
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            PrintHintText(i, "<font color='#FFD700'>%s</font>\nhat GunGame gewonnen!", name);
        }
    }
}

FreezeAllPlayers(bool:freeze)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
            SetEntityMoveType(i, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
    }
}

public Action:Timer_Unfreeze(Handle:timer)
{
    FreezeAllPlayers(false);
    return Plugin_Stop;
}

public Action:Cmd_ChangeNow(client, args)
{
    DoMapChange();
    return Plugin_Handled;
}

public Action:Timer_ChangeMap(Handle:timer)
{
    DoMapChange();
    return Plugin_Stop;
}

DoMapChange()
{
    decl String:map[PLATFORM_MAX_PATH];
    map[0] = '\0';

    new Handle:cv = FindConVar("sm_nextmap");
    if (cv != INVALID_HANDLE)
        GetConVarString(cv, map, sizeof(map));

    if (map[0] != '\0' && IsMapValid(map))
    {
        PrintToChatAll("\x04[GunGame]\x01 Wechsel zur naechsten Map: \x03%s", map);
        LogMessage("[GunGame] Winner declared - changing map to %s", map);
        ForceChangeLevel(map, "GunGame winner - next map");
    }
    else
    {
        LogError("[GunGame] Winner declared but sm_nextmap ('%s') is not a valid map - no change.", map);
        g_bChanging = false;
    }
}
