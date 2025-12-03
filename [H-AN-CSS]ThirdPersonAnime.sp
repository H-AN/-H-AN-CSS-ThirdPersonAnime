#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <HanAnimeAPI>

public Plugin myinfo =
{
    name = "第三人称外部附加动画API测试版本",
    author = "H-AN",
    description = "外部附加动画, 骨骼动画 API",
    version = "2.2",
    url = "https://github.com/H-AN"
};

enum struct Config
{
    ConVar HideWeapon;
    ConVar HidePlayer;
    ConVar Attachemnst;
    //ConVar Predictfix;
}
Config g_AnimeConfig;

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_BONEMERGE_FASTCULL       (1 << 7)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)
#define EFL_DONTBLOCKLOS		    (1 << 25)
#define SF_PHYSPROP_PREVENT_PICKUP	(1 << 9)

#define SPECMODE_NONE 				0
#define SPECMODE_FIRSTPERSON 		4
#define SPECMODE_3RDPERSON 			5
#define SPECMODE_FREELOOK	 		6

int g_PlayerAnim[MAXPLAYERS+1];    
int g_PlayerClone[MAXPLAYERS+1];   
int g_PlayerWeapon[MAXPLAYERS+1];  
bool g_PlayerSetTransmit[MAXPLAYERS+1]; 
bool g_WeaponSetTransmit[MAXPLAYERS+1]; 

char g_NeedPrecache[128][PLATFORM_MAX_PATH];
int g_ModelsCount = 0;

int offsCollision;

//bool IsPredict[MAXPLAYERS+1];

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("Han_SetPlayerAnime", Native_SetPlayerAnime);
    CreateNative("Han_KillAnime", Native_KillAnime);
    return APLRes_Success;
}

public void OnPluginStart()
{
    offsCollision = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

    g_AnimeConfig.HideWeapon = CreateConVar("anime_hideweapon", "1", "是否隐藏武器实体, 1隐藏 0 不隐藏 测试用");
    g_AnimeConfig.HidePlayer = CreateConVar("anime_hideplayer", "1", "是否隐藏玩家本体, 1隐藏 0 不隐藏 测试用");
    //g_AnimeConfig.Predictfix = CreateConVar("anime_predictfix", "0", "是否开启 预测修复,当使用不预测本地客户端的第三人称时");
    //g_AnimeConfig.Attachemnst= CreateConVar("anime_att", "muzzle_flash", "绑定附件位置测试填写附件名字来更改");

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
    int AnimeModelcount = ExplodeString(Models, ",", AnimeModel, sizeof(AnimeModel), sizeof(AnimeModel[]));
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
    
    /*
    if(GetConVarBool(g_AnimeConfig.Predictfix))
    {
        if(!IsFakeClient(client))
        {
            QueryClientConVar(client, "sv_client_predict", ConVarQueryFinished:ClientConVar, client);
        }

    }
    */
    
    int Ent = EntRefToEntIndex(g_PlayerAnim[client]);
	if (Ent && Ent != INVALID_ENT_REFERENCE && IsValidEntity(Ent))
	{
        HideWeaponAndPlayer(client, true);
    }
    else
    {
        HideWeaponAndPlayer(client, false);
    }
    return Plugin_Continue;
}


public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)  //玩家死亡删除两个实体
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsValidClient(client))
	{
		KillAnime(client); 
        KillClone(client);
        KillFakeWeapon(client);
	}

    return Plugin_Continue;
}


public void SetPlayerAnime(int client, const char[] animName, float duration, const float angAdjust[3], bool selfVisible, bool hideWeapon, bool loop)
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


    SetEntityRenderMode(cloneEnt, RENDER_TRANSALPHA);
    SetEntityRenderColor(cloneEnt, 255, 255, 255, 0);
    CreateTimer(0.1, ShowFakeEnt, cloneEnt);
    /*
    if(GetConVarBool(g_AnimeConfig.Predictfix)) //不预测修复
    {
        SetEntityRenderMode(cloneEnt, RENDER_TRANSALPHA);
        SetEntityRenderColor(cloneEnt, 255, 255, 255, 0);
        CreateTimer(0.1, ShowFakeEnt, cloneEnt);
    }
    */

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

    CreateFakeWeapon(client, animEnt, vec, ang);
    

    g_PlayerSetTransmit[client] = selfVisible;
    SDKHook(EntIndexToEntRef(cloneEnt), SDKHook_SetTransmit, SetTransmit_CallBack);

    g_WeaponSetTransmit[client] = hideWeapon;

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

void CreateFakeWeapon(int client, int entity, float vec[3], float ang[3])
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    KillFakeWeapon(client);

    int Weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(Weapon <= 0)
        return;

    char Wmodels[64]
    findModelString(GetEntProp(Weapon, Prop_Send, "m_iWorldModelIndex"), Wmodels, sizeof(Wmodels));
    PrecacheModel(Wmodels, true);

    int fakeEnt = CreateEntityByName("prop_dynamic_override");
    if (!IsValidEntity(fakeEnt)) 
        return;
    
    SDKHook(fakeEnt, SDKHook_Use, OnUse);
    DispatchKeyValue(fakeEnt, "model", Wmodels);
    DispatchKeyValue(fakeEnt, "solid", "0");
	DispatchKeyValue(fakeEnt, "spawnflags", "256");
	DispatchSpawn(fakeEnt);

    SetEntPropEnt(fakeEnt, Prop_Send, "m_hOwnerEntity", client);

    SDKHook(EntIndexToEntRef(fakeEnt), SDKHook_SetTransmit, SetTransmit_WeaponCallBack);

    SetEntityRenderMode(fakeEnt, RENDER_TRANSALPHA);
    SetEntityRenderColor(fakeEnt, 255, 255, 255, 0);

    g_PlayerWeapon[client] = EntIndexToEntRef(fakeEnt);
    
    TeleportEntity(fakeEnt, vec, ang, NULL_VECTOR);


    AcceptEntityInput(fakeEnt, "DisableShadow");

    SetEntData(fakeEnt, offsCollision, 2, 1, true); // 无碰撞

    SetEntProp(fakeEnt, Prop_Data, "m_nSkin", GetEntProp(Weapon, Prop_Data, "m_nSkin"));
	SetEntProp(fakeEnt, Prop_Data, "m_iEFlags", GetEntProp(fakeEnt, Prop_Data, "m_iEFlags") | EFL_DONTBLOCKLOS | SF_PHYSPROP_PREVENT_PICKUP);
	SetEntProp(fakeEnt, Prop_Send, "m_nSolidType", 6, 1);
     
    
    SetVariantString("!activator");
    AcceptEntityInput(fakeEnt, "SetParent", entity, entity, 0);
    
    //char attachment[64];
    //GetConVarString(g_AnimeConfig.Attachemnst, attachment, sizeof(attachment));
    //char buffer[256];
    //Format(buffer, sizeof(buffer), "!self,SetParentAttachmentMaintainOffset,%s,0.1,-1", attachment);
    //DispatchKeyValue(fakeEnt, "OnUser1", buffer);

    SetVariantString("OnUser1 !self,SetParentAttachmentMaintainOffset,muzzle_flash,0.1,-1");
    AcceptEntityInput(fakeEnt, "AddOutput");
    AcceptEntityInput(fakeEnt, "FireUser1");

    int iFlags = GetEntProp(fakeEnt, Prop_Data, "m_usSolidFlags", 2);
	iFlags = iFlags |= 0x0004;
	SetEntProp(fakeEnt, Prop_Data, "m_usSolidFlags", iFlags, 2);

    CreateTimer(0.1, ShowFakeEnt, fakeEnt);

    

}

public Action ShowFakeEnt(Handle timer, any fakeEnt)
{
    int Ent = EntIndexToEntRef(fakeEnt)
    if (Ent != -1 && IsValidEdict(Ent))
    {
        SetEntityRenderMode(Ent, RENDER_TRANSALPHA);
        SetEntityRenderColor(Ent, 255, 255, 255, 255);
    }
    return Plugin_Continue; 
}


Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	return Plugin_Handled;
}

int findModelString(int modelIndex, char[] modelString, int string_size)
{
	static int stringTable = INVALID_STRING_TABLE;
	if( stringTable == INVALID_STRING_TABLE )
	{
		stringTable = FindStringTable("modelprecache");
	}
	return ReadStringTable(stringTable, modelIndex, modelString, string_size);
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

void KillFakeWeapon(int client)
{
    if (!g_PlayerWeapon[client])
        return;

    int ent = EntRefToEntIndex(g_PlayerWeapon[client]);
    if (ent != -1 && IsValidEdict(ent))
    {
        HideCloneOrAnime(ent);
        DispatchKeyValue(ent, "OnUser1", "!self,Kill,,1.0,-1");
        AcceptEntityInput(ent, "FireUser1");

        g_PlayerWeapon[client] = 0;
    }
    else
    {
        g_PlayerWeapon[client] = 0;
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

public Action SetTransmit_WeaponCallBack(entity, viewer)
{
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if(viewer > 0 && viewer <= MaxClients)
    {
        if(owner == viewer && !g_WeaponSetTransmit[owner])
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
    //int EntEffects = GetEntProp(client, Prop_Send, "m_fEffects");
    if (hide)
    {
        if(GetConVarBool(g_AnimeConfig.HidePlayer))
        {
            CreateTimer(0.1, DelayHide, client);
            /*
            if(GetConVarBool(g_AnimeConfig.Predictfix))
            {
                CreateTimer(0.1, DelayHide, client);
            }
            else
            {
                //EntEffects |= 32;
                //SetEntProp(client, Prop_Send, "m_fEffects", EntEffects); 
                SetEntityRenderMode(client, RENDER_TRANSALPHA);
                SetEntityRenderColor(client, 255, 255, 255, 0);
            }
            */
        }
        if (weapon != -1)
        {
            if(GetConVarBool(g_AnimeConfig.HideWeapon))
            {
                SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
                SetEntityRenderColor(weapon, 255, 255, 255, 0);
            }

        }
    }
    else
    {
        //EntEffects &= ~32;
        //SetEntProp(client, Prop_Send, "m_fEffects", EntEffects);
        SetEntityRenderMode(client, RENDER_TRANSALPHA);
        SetEntityRenderColor(client, 255, 255, 255, 255);
        if (weapon != -1)
        {
            SetEntityRenderMode(weapon, RENDER_TRANSALPHA);
            SetEntityRenderColor(weapon, 255, 255, 255, 255);
        }
    }
}

public Action DelayHide(Handle timer, any client)
{
    //int EntEffects = GetEntProp(client, Prop_Send, "m_fEffects");
    //EntEffects |= 32;
    //SetEntProp(client, Prop_Send, "m_fEffects", EntEffects); 
    SetEntityRenderMode(client, RENDER_TRANSALPHA);
    SetEntityRenderColor(client, 255, 255, 255, 0);
            
    return Plugin_Continue; 
}

/*
public ClientConVar(QueryCookie cookie, client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
    if(StrEqual(cvarValue, "0"))
    {
        IsPredict[client] = false;
    }
    else if(StrEqual(cvarValue, "1") ||StrEqual(cvarValue, "-1") )
    {
        IsPredict[client] = true;
    }
    else
    {
        IsPredict[client] = true;
    }
} 
*/
public int Native_SetPlayerAnime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char animName[64];
    GetNativeString(2, animName, sizeof(animName));

    float duration = GetNativeCell(3);

    float angAdjust[3];
    GetNativeArray(4, angAdjust, sizeof(angAdjust));

    bool selfVisible = GetNativeCell(5);

    bool hideWeapon = GetNativeCell(6);

    bool loop = GetNativeCell(7);

    SetPlayerAnime(client, animName, duration, angAdjust, selfVisible, hideWeapon, loop);
    return 1;
}

public int Native_KillAnime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    KillAnime(client);
    KillClone(client);
    KillFakeWeapon(client);
    return 1;
}

public void OnClientDisconnect(int client)
{
    g_PlayerAnim[client] = 0;
    g_PlayerClone[client] = 0;
    g_PlayerWeapon[client] = 0;
    g_PlayerSetTransmit[client] = false;
}
