/**
 * Bot Balance - keep "humans + N" bots
 * ------------------------------------
 * Keeps the number of bots at (human player count + sm_botbalance_extra).
 * Bots are kept on one team and humans on the other via the server.cfg
 * cvars  bot_join_team  and  mp_humanteam  (this plugin only manages the
 * bot COUNT, not the team assignment).
 *
 * Cvar (cfg/sourcemod/bot_balance.cfg):
 *   sm_botbalance_extra  2   - how many MORE bots than human players
 */

#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvExtra;
ConVar g_cvQuota;
ConVar g_cvQuotaMode;
Handle g_hTimer = null;

public Plugin myinfo =
{
    name        = "Bot Balance",
    author      = "Claude",
    description = "Keeps bot count at human players + N",
    version     = "1.0.0",
    url         = ""
};

public void OnPluginStart()
{
    g_cvExtra     = CreateConVar("sm_botbalance_extra", "2", "Number of bots above the human player count.", _, true, 0.0, true, 32.0);
    g_cvQuota     = FindConVar("bot_quota");
    g_cvQuotaMode = FindConVar("bot_quota_mode");

    HookEvent("player_team",       Event_Changed, EventHookMode_PostNoCopy);
    HookEvent("player_disconnect", Event_Changed, EventHookMode_PostNoCopy);

    AutoExecConfig(true, "bot_balance");
}

public void OnConfigsExecuted() { Schedule(); }
public void OnMapStart()        { Schedule(); }
public void OnClientPutInServer(int client) { if (!IsFakeClient(client)) Schedule(); }
public void OnClientDisconnect_Post(int client) { Schedule(); }

void Event_Changed(Event event, const char[] name, bool dontBroadcast) { Schedule(); }

void Schedule()
{
    // Debounce: collapse rapid events into a single recount.
    if (g_hTimer != null)
    {
        KillTimer(g_hTimer);
        g_hTimer = null;
    }
    g_hTimer = CreateTimer(1.5, Timer_Apply);
}

public Action Timer_Apply(Handle timer)
{
    g_hTimer = null;

    int humans = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
            humans++;
    }

    int want = humans + g_cvExtra.IntValue;

    if (g_cvQuotaMode != null)
        g_cvQuotaMode.SetString("normal");   // bot_quota = absolute number of bots
    if (g_cvQuota != null)
        g_cvQuota.SetInt(want);

    return Plugin_Stop;
}
