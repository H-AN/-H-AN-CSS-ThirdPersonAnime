    CS起源创建第三人称动画实体附加API
 
    轻松创建第三人称动画, 滑铲,奔跑,踢腿 等等.

    使用此API需要骨骼动画模型支持, 感谢杰西制作的滑铲骨骼动画

    角度修复 根据骨骼动画制作者 可能会导致动画未能对齐 

    先 float angles[3] = {0.0, 90.0, 0.0}; 先声明一个角度 之后在用api修复角度
 
 * 播放第三人称外部动画
 *
 * @param client        玩家
 * @param animName      QC 动画名称
 * @param duration      持续时间
 * @param angAdjust     角度偏移 {pitch, yaw, roll}
 * @param selfVisible   玩家是否能看到自己的动画
 * @param loop   动画循环

   native void Han_SetPlayerAnime(int client, const char[] animName, float duration,const float angAdjust[3], bool selfVisible = false, bool loop);

 * 删除动画实体 *

   native void Han_KillAnime(int client);

 * API  设置动画  动画qc名称  持续时间 纠正动画角度 是否能看见自己的动画实体 动画循环 

   示例 Han_SetPlayerAnime(client, "huachan", 1.5, vangles, false, false); 

 * API 直接删除动画 

   Han_KillAnime(client);  

