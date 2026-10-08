# 第一章地图暂停交付

用户于 2026-10-09 要求提交已开发成果并暂停后续工作。本 PR 保存现有代码、真实素材和阶段证据；不是整图完成或验收通过声明。

## 已保存

- WORLD 来源：d8a3358、ca7f756、362bfd28438b2891cf91032564206abdeb4c60e2。112×64 的 farm 与 80×40 的 village，由 Godot TileMapLayer 和独立 PackedScene 组成。
- 最新地图修复：实例内部 owner 保留、河水层级、河岸测试探针、门交互位置、围栏、九块视觉菜床与萝卜装饰。六个玩法 plot_id 和既有 Space/存档合同保留。
- terrain 来源 5bbe5c5；river 6217f714；objects c8aadfb9；town 4bede504；animals 7d908da。source/runtime/reviews 含真实 PNG、PXO、rect/anchor、job/provenance、SHA256 和 8× 最近邻预览。所有素材仍为 proposed。
- QA 来源 bfdfa12、c9d269f、0e3d172。旧基础层成功和 ca7f756 失败按源提交分目录保留，不相互替代。

## 验证范围

WORLD 在最终 362bfd2 上已执行 Godot 4.7.2 headless：world_layout_test 35/0，phase0_visual_contract_test 33/0，farm_exploration_test 12/0，village_shop_route_test 19/0；作者另做房屋移动诊断，7 个 child 均在树内，碰撞跟随移动。

独立 QA 对 ca7f756 的真实输入路线 65 检查/1 失败（005 被稻草人阻挡，后续动作/桥/门/交易/存读档未执行）；编辑性 54/4 失败，布局 33/2 失败，并有大量节点退出泄漏。这些证据保存于 ../map_qa/checkpoint_ca7f756/。最终 owner 与布局修复尚未独立重跑，不推断全部失败已消除。

本目录三张 PNG 为 WORLD 在暂停前捕获的原生 SubViewport 图像，SHA 在 manifest.json；截图脚本退出有清理告警，不证明完整玩法。用户要求暂停后，综合分支未新增 Godot 测试，只做 Git diff/check、来源及 PNG 字节一致性核对。

## 未验收与恢复入口

整图构图/密度/像素风格人工签收、最终六田动作及完整桥岸/八门/经济/存档路线、编辑器实际编辑扩图、冷导入/导出发布均未最终验收。未来恢复从本 PR head 开始，在隔离 worktree 重新运行独立 QA；不要拿 d8a3358 的基础层 46/0 与 52/0 代表新地图。

运行入口是仓库 game/project.godot；从 Codex worktree 或检出本 PR 的仓库在 Godot 打开该项目。旧 main 工作树未改动，未部署、未合并、未关闭 Issue。
