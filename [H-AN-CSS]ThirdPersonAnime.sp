#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <HanAnimeAPI>

public Plugin myinfo =
{
    name = "第三人称外部附加动画API",
    author = "H-AN",
    description = "外部附加动画, 骨骼动画 API",
    version = "1.0",
    url = "https://github.com/H-AN"
};

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_BONEMERGE_FASTCULL       (1 << 7)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

int g_PlayerAnim[MAXPLAYERS+1];    
int g_PlayerClone[MAXPLAYERS+1];   
bool g_PlayerSetTransmit[MAXPLAYERS+1]; 

char g_NeedPrecache[128][PLATFORM_MAX_PATH];
int g_ModelsCount = 0;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("Han_SetPlayerAnime", Native_SetPlayerAnime);
    CreateNative("Han_KillAnime", Native_KillAnime);
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void OnMapStart()
{
    LoadPrecache();
}

void LoadPrecache()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/HanAnimeAPI.cfg");

    if (!FileExists(path))
    {
        WriteDefaultConfig(path);
        PrintToServer("[HanAnimeAPI] 配置文件不存在，已生成默认配置！");
    }

    KeyValues kv = new KeyValues("HanAnimeAPI");
    if (!FileToKeyValues(kv, path))
    {
        PrintToServer("[HanAnimeAPI] 配置读取失败！");
        delete kv;
        return;
    }

    char Models[512];
    KvGetString(kv, "PrecacheAnimeModel", Models, sizeof(Models));
    TrimString(Models);

    // 分割字符串
    char AnimeModel[128][PLATFORM_MAX_PATH];
    int AnimeModelcount = ExplodeString(Models, ",", AnimeModel, sizeof(AnimeModel), sizeof(AnimeModel[0]));
    g_ModelsCount = 0;

    for (int i = 0; i < AnimeModelcount && g_ModelsCount < 16; i++)
    {
        TrimString(AnimeModel[i]);
        if (strlen(AnimeModel[i]) == 0) continue;

        strcopy(g_NeedPrecache[g_ModelsCount], sizeof(g_NeedPrecache[]), AnimeModel[i]);

        PrecacheModel(g_NeedPrecache[g_ModelsCount], true);
        PrintToServer("[HanAnimeAPI] 预缓存骨骼动画模型[%d]: %s", g_ModelsCount, g_NeedPrecache[g_ModelsCount]);
        g_ModelsCount++;
    }
    delete kv;
}

void WriteDefaultConfig(const char[] path)
{
    Handle file = OpenFile(path, "w");
    if (file == INVALID_HANDLE) return;

    WriteFileLine(file, "// HanAnimeAPI 配置文件");
    WriteFileLine(file, "// PrecacheAnimeModel 预缓存骨骼动画");
    WriteFileLine(file, "\"HanAnimeAPI\"");
    WriteFileLine(file, "{");
    WriteFileLine(file, "    \"PrecacheAnimeModel\"    \"models/player/custom_anime/customnnime.mdl\"");
    WriteFileLine(file, "}");

    CloseHandle(file);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(!IsValidClient(client))
        return Plugin_Continue;
    
    int Ent = EntRefToEntIndex(g_PlayerAnim[client]);
	if (Ent && Ent != INVALID_ENT_REFERENCE && IsValidEntity(Ent))
	{
        HideWeaponAndPlayer(client, true);
    }
    else
    {
        HideWeaponAndPlayer(client, false);
    }
}


public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)  //玩家死亡删除两个实体
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		KillAnime(client); 
        KillClone(client);
	}

    return Plugin_Continue;
}


public void SetPlayerAnime(int client, const char[] animName, float duration, const float angAdjust[3], bool selfVisible, bool loop)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    KillAnime(client);
    KillClone(client);

    char modelPath[PLATFORM_MAX_PATH];
    strcopy(modelPath, sizeof(modelPath), g_NeedPrecache[0]);

    char animTarget[32], cloneTarget[32];
    Format(animTarget, sizeof(animTarget), "AnimeEnt_%d_anim", GetRandomInt(1000000, 9999999));
    Format(cloneTarget, sizeof(cloneTarget), "AnimeEnt_%d_clone", GetRandomInt(1000000, 9999999));

    float vec[3], ang[3];
    GetClientAbsOrigin(client, vec);
    GetClientAbsAngles(client, ang);

    ang[0] += angAdjust[0];
    ang[1] += angAdjust[1];
    ang[2] += angAdjust[2];

    int animEnt = CreateEntityByName("prop_dynamic");
    if (animEnt == -1) return;
    DispatchKeyValue(animEnt, "targetname", animTarget);
    DispatchKeyValue(animEnt, "model", modelPath);
    DispatchKeyValue(animEnt, "solid", "0");
    DispatchKeyValue(animEnt, "rendermode", "10");
    ActivateEntity(animEnt);
    DispatchSpawn(animEnt);

    SetEntPropEnt(animEnt, Prop_Send, "m_hOwnerEntity", client);

    SetEntityMoveType(animEnt, MOVETYPE_NOCLIP);
    TeleportEntity(animEnt, vec, ang, NULL_VECTOR);

    SetVariantString(animName);
    AcceptEntityInput(animEnt, "SetDefaultAnimation");
    SetEntPropFloat(animEnt, Prop_Send, "m_flPlaybackRate", 1.0);

    int cloneEnt = CreateEntityByName("prop_dynamic");
    if (cloneEnt == -1) { RemoveEntity(animEnt); return; }
    DispatchKeyValue(cloneEnt, "targetname", cloneTarget);
    char playerModel[64];
    GetEntPropString(client, Prop_Data, "m_ModelName", playerModel, sizeof(playerModel));
    PrecacheModel(playerModel, true);
    DispatchKeyValue(cloneEnt, "model", playerModel);
    DispatchSpawn(cloneEnt);

    SetEntPropEnt(cloneEnt, Prop_Send, "m_hOwnerEntity", client);

    SetEntityMoveType(cloneEnt, MOVETYPE_NONE);
    TeleportEntity(cloneEnt, vec, ang, NULL_VECTOR);
    SetEntProp(cloneEnt, Prop_Send, "m_fEffects",EF_BONEMERGE | EF_NOSHADOW | EF_NORECEIVESHADOW |EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES);

    AcceptEntityInput(cloneEnt, "ClearParent");
    SetVariantString(animTarget);
    AcceptEntityInput(cloneEnt, "SetParent", animEnt, animEnt, 0);

    SetVariantString("OnUser1 !self,SetParentAttachmentMaintainOffset,primary,0.1,-1");
    AcceptEntityInput(cloneEnt, "AddOutput");
    AcceptEntityInput(cloneEnt, "FireUser1");

    AcceptEntityInput(animEnt, "ClearParent");
    SetVariantString("!activator");
    AcceptEntityInput(animEnt, "SetParent", client, client, 0);

    SetVariantString("OnUser1 !self,SetParentAttachmentMaintainOffset,primary,0.1,-1");
    AcceptEntityInput(animEnt, "AddOutput");
    AcceptEntityInput(animEnt, "FireUser1");

    g_PlayerSetTransmit[client] = selfVisible;
    SDKHook(EntIndexToEntRef(cloneEnt), SDKHook_SetTransmit, SetTransmit_CallBack);

    g_PlayerAnim[client] = EntIndexToEntRef(animEnt);
    g_PlayerClone[client] = EntIndexToEntRef(cloneEnt);

    if(loop)
    {
        DataPack AnimePack = new DataPack();
        AnimePack.WriteCell(EntIndexToEntRef(animEnt));
        AnimePack.WriteString(animName);

        CreateTimer(duration, AnimeLoopCallback, AnimePack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        SetEntityAutoKill(animEnt, duration);
        SetEntityAutoKill(cloneEnt, duration);
        
    }
}

public Action AnimeLoopCallback(Handle timer, DataPack AnimePack)
{
    AnimePack.Reset();
    int animEntRef = AnimePack.ReadCell();
    int animEnt = EntRefToEntIndex(animEntRef);

    char animName[64];
    AnimePack.ReadString(animName, sizeof(animName));

    

    if (!IsValidEntity(animEnt))
    {
        CloseHandle(AnimePack);
        return Plugin_Stop;
    }

    SetVariantString(animName);
    AcceptEntityInput(animEnt, "SetAnimation");

    return Plugin_Continue; 
}


void SetEntityAutoKill(int ent, float duration)
{
    if (ent == -1) return;

    char cmd[64];
    Format(cmd, sizeof(cmd), "!self,Kill,,%0.1f,-1", duration);
    DispatchKeyValue(ent, "OnUser1", cmd);
    AcceptEntityInput(ent, "FireUser1");
}

void KillAnime(int client)
{
    if (!g_PlayerAnim[client])
        return;

    int ent = EntRefToEntIndex(g_PlayerAnim[client]);
    if (ent != -1 && IsValidEdict(ent))
    {
        HideCloneOrAnime(ent);
        char entName[64];
        GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));

        SetVariantString(entName);
        AcceptEntityInput(client, "ClearParent", ent, ent, 0);

        DispatchKeyValue(ent, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(ent, "FireUser1");

        g_PlayerAnim[client] = 0;
    }
    else
    {
        g_PlayerAnim[client] = 0;
    }
}

void KillClone(int client)
{
    if (!g_PlayerClone[client])
        return;

    int ent = EntRefToEntIndex(g_PlayerClone[client]);
    if (ent != -1 && IsValidEdict(ent))
    {
        HideCloneOrAnime(ent);
        DispatchKeyValue(ent, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(ent, "FireUser1");

        g_PlayerClone[client] = 0;
    }
    else
    {
        g_PlayerClone[client] = 0;
    }
}

public Action SetTransmit_CallBack(entity, viewer)
{
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if(viewer > 0 && viewer <= MaxClients)
    {
        if(owner == viewer && !g_PlayerSetTransmit[owner])
        {
            return Plugin_Handled; 
        }
    }
    
    return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

void HideCloneOrAnime(int Ent)
{
    int EntEffects = GetEntProp(Ent, Prop_Send, "m_fEffects");
    EntEffects |= 32;
    SetEntProp(Ent, Prop_Send, "m_fEffects", EntEffects); 
}

void HideWeaponAndPlayer(int client, bool hide)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int EntEffects = GetEntProp(client, Prop_Send, "m_fEffects");
    if (hide)
    {
        EntEffects |= 32;
        SetEntProp(client, Prop_Send, "m_fEffects", EntEffects); 
        if (weapon != -1)
        {
            SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
            SetEntityRenderColor(weapon, 255, 255, 255, 0);
            SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
        }
    }
    else
    {
        EntEffects &= ~32;
        SetEntProp(client, Prop_Send, "m_fEffects", EntEffects);
        if (weapon != -1)
        {
            SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
            SetEntityRenderColor(weapon, 255, 255, 255, 255);
            SetEntProp(client, Prop_Send, "m_iAddonBits", 1);
        }
    }
}

public int Native_SetPlayerAnime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char animName[64];
    GetNativeString(2, animName, sizeof(animName));

    float duration = GetNativeCell(3);

    float angAdjust[3];
    GetNativeArray(4, angAdjust, sizeof(angAdjust));

    bool selfVisible = GetNativeCell(5);

    bool loop = GetNativeCell(6);

    SetPlayerAnime(client, animName, duration, angAdjust, selfVisible, loop);
    return 1;
}

public int Native_KillAnime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    KillAnime(client);
    KillClone(client);
    return 1;
}

public void OnClientDisconnect(int client)
{
    g_PlayerAnim[client] = 0;
    g_PlayerClone[client] = 0;
    g_PlayerSetTransmit[client] = false;
}
