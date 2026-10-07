# 开发流程与 Agent 协作

唯一[总任务 #1](https://github.com/natefox2017/qingfeng/issues/1)。[任务登记](tasks.json)只保存身份、链接和依赖；完成状态在 Issue，不在文档复制第二份。

## 从成熟做法到本项目
[参考](references.md)中的图块编辑/共享场景、游戏输入与慢请求分离，转成三个规则：布局先在引擎确定；素材按可复用组件交付；玩家可操作的纵向切片短周期合入。AI Town是技术参考，不把它说成商业农场成品。
先一屏比例/工具动作样板，先种植—背包—休息—存档闭环，最后扩大村庄与居民内容。不要重建整个游戏后才第一次试走。

## 任务与依赖
| Task | 负责人边界 | 可并行与依赖 |
| --- | --- | --- |
| N01 | PixelLab接通、风格样板/资产规则 | 可先做；付费任务要账户和预算 |
| N02 | 地形/对象/物品图集 | N01风格；不改玩法 |
| N03 | 人犬四向、农事动画 | N01身份；与N02并行 |
| N04 | 公共字段、状态、时钟、存档 | 合同可先做；运行接N05 |
| N05 | Godot工程、地图、碰撞、人犬 | 脚手架可先做；正式图依赖N02/N03 |
| N06 | 农耕、库存、经济 | N04接口，表现依赖N02/N03 |
| N07 | 图标UI、字体、真实页面 | 框架可先做；命令依赖N04/N06 |
| N08 | 三居民生活和知情记忆 | N04时间/事件、N05导航 |
| N09 | 指引、委托、故事和狗经历 | 文本可先写；集成N06/N08 |
| N10 | 可选居民AI表达 | FakeProvider可先做；不阻离线交付 |
| N11 | 整合试玩、日志、桌面导出 | N05–N09；N10随包则测隔离 |

N04拥有公共schema/时钟/保存；N05拥有app入口/同地图；N11协调公共CI。其他agent先请求接口，不能并行修改同一文件或复制状态。资产请求由N01/N02/N03处理，位置变化由N05处理，不互相推诿到“重画整图”。

## 每个小步骤
认领最新SHA/分支/文件 → 阅读对应官方能力与依赖 → 提交最小合同/可失败测试 → 实现 → 正常/失败/取消/保存验证 → 适用原生画面 → 普通PR → 合入复核 → 勾该checkbox。
依赖最终图的场景接入等待对应图，领域命令和物理夹具可独立做。pending生成期间处理无冲突的代码/数据，不忙轮询也不重复下单。

## PR规则
分支 feat/fix/refactor/docs/art/test/chore 加语义任务名。PR默认非Draft，一项可验证能力；大Issue通过多个短PR完成。禁止force push、覆盖用户未提交工作或未经检查合并无关PR。
PR用 [模板](../.github/PULL_REQUEST_TEMPLATE.md)，注明实际来源、运行入口、测试证据、保存语义、未验项。预算授权、视觉接受、功能完成三个结论分别写，不互相替代。
main实际规则要求`repository-policy`检查通过；它执行真实框架、工具、引擎冷导入和物理/生命周期回归，不是恒绿占位。其他游戏验收仍由review逐项核对，不能凭这一检查替代未覆盖功能；不修改或绕过仓库保护。

## 当前检查与阶段
```sh
python3 tools/check_scaffold.py
python3 -m unittest discover -s tools/tests -v
```
上面的命令只检查文档/工具；当前foundation引擎回归另执行 `python3 tools/runtime.py test`，详见[运行基础](runtime_foundation.md)。scaffold没有可启动工程；preproduction有新素材但未接正式运行；foundation开始须有固定引擎版本、project.godot、正式main_scene和真实游戏CI；playable必须N11验收。
阶段由project.json唯一声明，README/Notion同步。不能把本次工具测试数字当新游戏回归。变更交接用[handoff](../templates/handoff.md)，不另造多套总册。

## 实际任务链接
- [N01 / #2：PixelLab连接与风格样板](https://github.com/natefox2017/qingfeng/issues/2)
- [N02 / #3：地形与对象图集](https://github.com/natefox2017/qingfeng/issues/3)
- [N03 / #4：人犬与农事动画](https://github.com/natefox2017/qingfeng/issues/4)
- [N04 / #5：公共状态时间存档](https://github.com/natefox2017/qingfeng/issues/5)
- [N05 / #6：引擎地图人犬](https://github.com/natefox2017/qingfeng/issues/6)
- [N06 / #7：农耕库存经济](https://github.com/natefox2017/qingfeng/issues/7)
- [N07 / #8：图标UI字体](https://github.com/natefox2017/qingfeng/issues/8)
- [N08 / #9：居民生活记忆](https://github.com/natefox2017/qingfeng/issues/9)
- [N09 / #10：指引委托故事](https://github.com/natefox2017/qingfeng/issues/10)
- [N10 / #11：可选AI表达](https://github.com/natefox2017/qingfeng/issues/11)
- [N11 / #12：原生试玩与导出](https://github.com/natefox2017/qingfeng/issues/12)
