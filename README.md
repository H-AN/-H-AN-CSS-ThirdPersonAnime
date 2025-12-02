    CS起源创建第三人称动画实体附加API
 
    轻松创建第三人称动画, 滑铲,奔跑,踢腿 等等.

    使用此API需要骨骼动画模型支持, 感谢杰西制作的滑铲骨骼动画

    角度修复 根据骨骼动画制作者 可能会导致动画未能对齐 

    先 float angles[3] = {0.0, 90.0, 0.0}; 先声明一个角度 之后在用api修复角度

    API使用方法 
    1. 将编译好的smx文件放入插件文件夹
    2. 将API文件 HanAnimeAPI.inc 放入 include 文件夹
    3. 在自己需要设置动画的插件内 #include <HanAnimeAPI>
    4. 根据API功能随意使用吧

    cavr
    anime_hideweapon 1  是否隐藏武器实体, 1隐藏 0 不隐藏 测试用
    anime_hideplayer 1 是否隐藏玩家本体, 1隐藏 0 不隐藏 测试用
    anime_predictfix 0 默认0 非预测修复, 默认关闭, 打开后将修复 关闭预测带来的延迟,动画错误(可选项)

 * 播放第三人称外部动画
 *
 * @param client        玩家
 * @param animName      QC 动画名称
 * @param duration      持续时间
 * @param angAdjust     角度偏移 {pitch, yaw, roll}
 * @param selfVisible   玩家是否能看到自己的动画
 * @param hideWeapon   玩家是否能看到自己的武器附加
 * @param loop   动画循环

   native void Han_SetPlayerAnime(int client, const char[] animName, float duration,const float angAdjust[3], bool selfVisible = false, bool hideWeapon = false, bool loop);

 * 删除动画实体 *

   native void Han_KillAnime(int client);

 * API  设置动画  动画qc名称  持续时间 纠正动画角度 是否能看见自己的动画实体 动画循环 

   示例 Han_SetPlayerAnime(client, "huachan", 1.5, vangles, false, false); 

 * API 直接删除动画 

   Han_KillAnime(client);  

