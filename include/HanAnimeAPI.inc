#if defined _THIRDPERSON_ANIM_INC_
    #endinput
#endif
#define _THIRDPERSON_ANIM_INC_

/**
 * 播放第三人称外部动画
 *
 * @param client        玩家
 * @param animName      QC 动画名称
 * @param duration      持续时间
 * @param angAdjust     角度偏移 {pitch, yaw, roll}
 * @param selfVisible   玩家是否能看到自己的动画
 * @param hideWeapon   玩家是否能看到自己的武器附加
 * @param loop   动画循环
 */
native void Han_SetPlayerAnime(int client, const char[] animName, float duration,const float angAdjust[3], bool selfVisible = false, bool hideWeapon = false, bool loop);

/** 删除动画实体 */
native void Han_KillAnime(int client);