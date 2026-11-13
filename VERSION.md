# 项目版本约定与变更台账

> 用户约定（2026-11-13）：**初始版本为 V0.0.1，后续慢慢升级**。

## 1. 两套版本号，别混

| 版本 | 对象 | 当前值 | 记在哪 |
|---|---|---|---|
| 文档版本 | `铁钩船长3D复刻-设计报告.md` / `.html` | v2.0 | 报告头部表格 + 附录 C |
| **项目版本** | 可运行的游戏程序（`hook3d/`） | **V0.6.0** | 本文件 + `project.godot` 的 `config/version` + README |

`project.godot` 里写 `0.1.0`（Godot 约定不带 V），文档写作 **V0.1.0**，两者是同一个版本。V0.0.1 是 M0 骨架期的历史版本。

## 2. 格式与递进规则

格式 `V主.次.补丁`：

- `0.0.x`：骨架 / 系统未成形阶段（M0）。每完成一次可验证的骨架改动 +1。
- `0.x.0`：一个里程碑交付可运行版本，按 M 阶段递增（M1 → V0.1.0，M2 → V0.2.0 …）。
- `0.9.0`：发布候选（RC，M9 打包前的完整版）。
- `1.0.0`：首个**内部定稿版**（路线 A，仅内部；不存在对外正式版）。
- 补丁位 `0.x.y`：同一个 M 阶段内的 Bug 修复与数值微调，不改范围。

**硬性规则**：只有「交付了可运行版本」才能升次版本号；只改文档/数据不算项目版本升级。每阶段结束时同步更新本文件、`project.godot`、`README.md` 与报告附录 C。

## 3. 里程碑 → 版本映射（规划）

| 阶段 | 版本 | 内容 | 状态 |
|---|---|---|---|
| M0 | V0.0.1 | 决策冻结、项目骨架、数据表、动线表 v0.9、私有 CI/CD | 已完成 |
| M1 | V0.1.0 | 首个可玩原型（1 角色 + 1 敌 + 1 段走廊 + 四连段/抓投/跳击/卡位） | 已交付 |
| M2 | V0.2.0 | 战斗系统完整（5 角色、7 类敌人、必杀、格挡、友伤） | 已交付 |
| M3 | V0.3.0 | 关卡框架 + HUD + TIME/飞鹰 + 分数 + 1–4 人中途加入 + 循环 | 已交付 |
| M4 | V0.4.0 | Stage 1–2 可玩（码头 / 雪原、BUTCHER / JASON、蜂窝 / 金笼 / 铁球 / 鸡群） | 已交付 |
| M5 | V0.5.0 | Stage 3–4 可玩（甲板 / 冰海、假 Hook、DAMON、罐子爆炸、长矛互投、冰柱反跳、企鹅） | 已交付 |
| M6 | **V0.6.0** | Stage 5–6 可玩，六关通关 + 结局（SMEE / HOOK、运财小兵 / 炮台、Tinker Bell、鳄鱼结局） | **当前 · 已交付** |
| M7 | V0.7.0 | 美术与音频打磨完成 | 未开始 |
| M8 | V0.8.0 | 平衡定稿、难度、隐藏要素、成就 | 未开始 |
| M9 | V0.9.0 → **V1.0.0** | RC → Windows + Web **内部定稿交付**（路线 A，仅内部） | 未开始 |

> 若中途插入小交付（例如提前做 Web 预览），按 `0.0.x` 递增，不占用里程碑版本号。

## 4. 变更台账

| 版本 | 日期 | 变更 | 依据 |
|---|---|---|---|
| V0.0.1 | 2026-11-13 | 初始骨架：Godot 4.3 项目、M0 骨架场景、14 个数据驱动 JSON、`validate_data.js`、双轨内容包清单、街机规则可插拔配置；**无游戏逻辑** | 报告 v1.1 第 9.7 / 10 章；用户版本约定 |
| V0.0.1（补记，不升号） | 2026-11-13 | 打通 GitHub CI/CD：新建私有仓库 `xinyule/hook`；新增 `export_presets.cfg`（Windows + Web）、`ci.yml`（数据/内容包/版本门禁）、`build-release.yml`（tag 触发双平台自动导出并发布 Release）；产出首个可运行的 M0 骨架程序包。因 M0 尚未收尾（逐帧复核待办），按「只有里程碑交付才升次版本」规则**仍保持 V0.0.1** | 用户「GitHub 建仓 / 推代码 / 构建发布」指令 |
| V0.0.1（路线变更，不升号） | 2026-11-13 | 用户取消 B 原创化对外路线，改为**单轨 A 忠实复刻（仅内部）**：`pack_manifest.json` 改单包 `internal_reference`（`distribution=internal_only`、`public_release=false`）；`validate_data.js` 与 `ci.yml` 门禁改为内部限定；移除 B 包候选产物名，产物统一用内部代号 `hook3d`；README / 报告同步；**明确不启用 GitHub Pages**。仅改决策与配置，未写游戏逻辑，故项目版本仍为 V0.0.1 | 用户「路线 A 忠实（仅内部）直接这个做」「不用 B 路线了」；报告 v1.4 |

| **V0.1.0** | 2026-11-13 | **M1 首个可玩原型**：3D 灰盒走廊 + 正交相机 + 实体屏幕边界；`hero_01`（PETERPAN）四连段快慢分支（Special / Heavy）、贴身抓投 5 下自动投出、跳击；`grunt` 三配色 AI；HUD；`--selftest` 26 项无头自测。新增 `data/combat_m1.json` 帧表与 A 包忠实对照名 `names_a.json`，`project.godot` 主场景改 `m1.tscn`、物理 60 tick；`tools/serve_web.py` 内网按需预览。报告 v1.5 新增 9.9.7 / 9.10。验收：自测全 PASS、双平台导出零警告、16 个 JSON 全进 pck、exe 冒烟 exit=0 | 报告 9.10；用户「按方案一步一步往下做，不用来回问我」；按 9.8.2 升次版本 |
| **V0.2.0** | 2026-11-13 | **M2 战斗系统完整**：五角色（PETERPAN/DON/JOHN/MICHAEL/POCKETS）独立招式表与差异；大招（A+B，扣 8% HP，低于 15% HP 禁用）、落地大招（6 帧窗口）、墙跳、空中投、背投、倒地追击（默认 4 击 / POCKETS 8）；七类敌人 AI（grunt/drunk/flyer/fatty/spearman/flail/swordsman）；命中去重、命中停顿分级（轻 4 / 重 7 / 必杀 10）、屏幕震动、命中粒子、友伤（含敌间友伤）、格挡（减伤 0.2）；`scenes/m2.tscn` 战斗沙盒（选人、生成、每帧模拟、判定打磨、相机/HUD）；headless 自测 30 项全 PASS。新增 `data/combat_m2.json` 招式帧表与 `data/enemies.json` 七类敌人模板；`project.godot` 主场景改 `m2.tscn`。验收：自测 30/30、数据校验 OK、Windows + Web 导出零警告、导出 exe 内自测 30/30、exe 冒烟 exit=0 | 报告 9.10.11；用户「游戏制作你继续进行」；按 9.8.2 升次版本 |
| **V0.3.0** | 2026-11-14 | **M3 关卡框架与 HUD**：StageRunner 段落流式加载（segments 按序推进、末段 Boss 场标记）；WaveDirector 按 wave 配置从 `enemies.json` 生成敌人、同屏上限约束（`balance.spawn.max_enemies_onscreen`）、波次清空推进；PlayerManager 4 槽位 1–4P 中途加入（起身无敌帧）、命数管理、投币续关；M3Timer TIME 递减 + 飞鹰（归零触发、推距、扣血、idle 阈值重复触发）；M3Score 击杀/连击/宝藏/隐藏点计分 + 周目倍率 + 隐藏点去重；M3Hud 4 条 HP 条 + 命数 + TIME 条 + 分数 + 周目计数；LoopManager 六关推进 + 末关回环周目 +1；规则集可插拔（arcade↔session）；`scenes/m3.tscn` 主场景；新增 `data/hud_m3.json` HUD 布局与飞鹰参数；headless 自测 42 项全 PASS。复用 M2 战斗核心不改。验收：自测 42/42、数据校验 OK、Windows + Web 导出零警告、导出 exe 内自测 42/42 | 报告 9.10.12；用户「继续往下进行，做完一个阶段直接做下一个」；按 9.8.2 升次版本 |
| **V0.4.0** | 2026-11-14 | **M4 Stage 1–2 可玩**：码头 / 雪原灰盒场景与光照预设（`m4_stage_scene`）；BUTCHER / JASON 招式状态机与击败演出（`m4_boss`，继承 M2Actor 接入 M3 敌人管线）；蜂窝拾取 / 携带 / 替换 / 两次替换自动释放、尖刺金笼安全位、铁球落点预警与压死演出、鸡群氛围与击败狂啄、可击碎物件与食物（`m4_props`）；stage_01 / stage_02 真实波次数据填充；Boss 血条 HUD；`scenes/m4.tscn` 主场景。新增 `data/bosses_m4.json`、`data/props_m4.json`，stage JSON 补 `spawn_props` / `lighting_preset`。复用 M2 战斗核心与 M3 框架层不改。工程修复（本阶段内）：铁球落地结算倒序遍历 `range(n-1,-1)` 缺步长 `-1` 导致空转，改 `range(n-1,-1,-1)`；Godot 4 `Array.erase()` 在 COW 下不生效，改 `remove_at()`。验收：headless 自测 **82 项全 PASS**（M3 42 + M4 40）、数据校验 20 文件通过、Windows + Web 导出零警告、导出 exe 内自测 82/82 | 报告 9.10.13；用户授权连续推进；按 9.8.2 升次版本 |
| **V0.5.0** | 2026-11-14 | **M5 Stage 3–4 可玩**：船甲板 / 冰海灰盒场景与光照预设（`m5_stage_scene`）；假 Hook（数量随人数 1 人 2 个 / 多人 3 个、可互投、无血条）与 DAMON（影子预警 / 气功波 / 冰柱当墙 / 踢击 / 击败演出，`m5_boss` 继承 M2Actor 接入 M3 敌人管线）；彩绘大罐爆炸（范围伤害 + 震屏）、长矛投掷与互投、冰柱可踩反跳、企鹅彩蛋隐藏点（`m5_props`）；stage_03 / stage_04 真实波次与 `spawn_props` / `lighting_preset` 填充；Boss 血条 HUD（仅真 Boss）；`scenes/m5.tscn` 主场景。新增 `data/bosses_m5.json`、`data/props_m5.json`。复用 M2 战斗核心与 M3 框架层不改。工程修复（本阶段内）：Godot 4 无 `ConeMesh`，冰山占位改 `BoxMesh`；假 Hook 段落地需 `on_floor=true` 才触发互投；企鹅需登记到 `prop_records` 才可击碎计分。验收：headless 自测 **102 项全 PASS**（M3 42 + M5 60）、数据校验 22 文件通过、Windows + Web 导出零警告、导出 exe 内自测 102/102 | 报告 9.10.14；用户授权连续推进；按 9.8.2 升次版本 |

| **V0.6.0** | 2026-11-14 | **M6 Stage 5–6 可玩 + 六关通关结局**：Stage 5 船舱 / 船长室（木条地板、原木墙、红金地毯、圆舷窗 + 红绒帷幕、雕花拱门、暖金烛光）与 Stage 6 决战甲板（木舱壁、拱形铁栅门、右上高台、高对比决战光照）灰盒场景与光照预设（`m6_stage_scene`）；SMEE（叩头禁跳打窗口、炮台三连发、近身挥砍、击败演出）与 HOOK（常规剑击 → 半血召唤杂兵刷新 + 钩击 → 低血全屏大招 / 冲撞，三阶段阈值数据驱动，击败演出跳起）招式状态机（`m6_boss` 继承 M2Actor 接入 M3 敌人管线）；运财小兵击打掉财宝计分、炮台三连发（落点预警）、Tinker Bell 高台回血 / 加分隐藏点、鳄鱼结局演出、可击碎物件（木箱 / 酒桶 / 装饰）；stage_05 / stage_06 真实波次与 `spawn_props` / `lighting_preset` 填充；六关完整通关 + 结局触发 + 末关回环周目；Boss 血条 HUD（SMEE / HOOK）；`scenes/m6.tscn` 主场景。新增 `data/bosses_m6.json`、`data/props_m6.json`。复用 M2 战斗核心与 M3 框架层不改。验收：headless 自测 **152 项全 PASS**（M5 102 + M6 50）、数据校验 24 文件通过、Windows + Web 导出零警告、导出 exe 内自测 152/152 | 报告 9.10.15；用户授权连续推进；按 9.8.2 升次版本 |

后续每次升级在此追加一行，写明：版本号、日期、改动摘要、对应报告版本与验收结论。

## 4.2 M1 云端发布记录（V0.1.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.1.0` |
| 产物 | `hook3d_v0.1.0_windows_x86_64.zip`、`hook3d_v0.1.0_web.zip` |
| 新增门禁 | CI 的 `selftest` job：Godot headless 先 `--editor --quit` 建立全局类缓存，再 `-- --selftest` 并断言 `SELFTEST PASS` |
| 运行方式 | 私有 Release 下载后，本机 `python tools/serve_web.py --dir build/web`，或内网设 `HOOK3D_WEB_PASSWORD` 后绑 `0.0.0.0`；**不启用 GitHub Pages** |
| 说明 | 仅内部；灰盒原型，不是成品关卡 |

## 4.3 M2 云端发布记录（V0.2.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.2.0` |
| 产物 | `hook3d_v0.2.0_windows_x86_64.zip`、`hook3d_v0.2.0_web.zip` |
| 门禁 | `validate_data.js`（17 文件 / 6 阶段 / 路线 A 单轨）+ CI `selftest` job（M2 30 项断言）+ 双平台导出 |
| 运行方式 | 同 V0.1.0：私有 Release 下载后本机运行 exe，或内网 `tools/serve_web.py` 预览；**不启用 GitHub Pages** |
| 说明 | 仅内部；战斗沙盒（五角色 + 七敌人 + 招式判定），非成品关卡 |

## 4.4 M3 云端发布记录（V0.3.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.3.0` |
| 产物 | `hook3d_v0.3.0_windows_x86_64.zip`、`hook3d_v0.3.0_web.zip` |
| 门禁 | `validate_data.js`（18 文件 / 6 阶段 / 路线 A 单轨）+ CI `selftest` job（M3 42 项断言）+ 双平台导出 |
| 运行方式 | 同 V0.1.0：私有 Release 下载后本机运行 exe，或内网 `tools/serve_web.py` 预览；**不启用 GitHub Pages** |
| 说明 | 仅内部；关卡框架 + HUD + TIME/飞鹰 + 分数 + 1–4P 加入 + 周目循环，非成品关卡（真实波次与 Boss 招式待 M4–M6） |

## 4.5 M4 云端发布记录（V0.4.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.4.0` |
| 产物 | `hook3d_v0.4.0_windows_x86_64.zip`、`hook3d_v0.4.0_web.zip` |
| 门禁 | `validate_data.js`（20 文件 / 6 阶段 / 路线 A 单轨）+ CI `selftest` job（M4 82 项断言）+ 双平台导出 |
| 运行方式 | 同 V0.1.0：私有 Release 下载后本机运行 exe，或内网 `tools/serve_web.py` 预览；**不启用 GitHub Pages** |
| 说明 | 仅内部；Stage 1–2 可玩（码头 / 雪原、BUTCHER / JASON、蜂窝 / 金笼 / 铁球 / 鸡群），Stage 3–6 待 M5 / M6 |

## 4.6 M5 云端发布记录（V0.5.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.5.0` |
| 产物 | `hook3d_v0.5.0_windows_x86_64.zip`、`hook3d_v0.5.0_web.zip` |
| 门禁 | `validate_data.js`（22 文件 / 6 阶段 / 路线 A 单轨）+ CI `selftest` job（M5 102 项断言）+ 双平台导出 |
| 运行方式 | 同 V0.1.0：私有 Release 下载后本机运行 exe，或内网 `tools/serve_web.py` 预览；**不启用 GitHub Pages** |
| 说明 | 仅内部；Stage 3–4 可玩（甲板 / 冰海、假 Hook、DAMON、罐子爆炸、长矛互投、冰柱反跳、企鹅），Stage 5–6 待 M6 |

## 4.7 M6 云端发布记录（V0.6.0）

| 项 | 值 |
|---|---|
| 发布 tag | `v0.6.0` |
| 产物 | `hook3d_v0.6.0_windows_x86_64.zip`、`hook3d_v0.6.0_web.zip` |
| 门禁 | `validate_data.js`（24 文件 / 6 阶段 / 路线 A 单轨）+ CI `selftest` job（M6 152 项断言）+ 双平台导出 |
| 运行方式 | 同 V0.1.0：私有 Release 下载后本机运行 exe，或内网 `tools/serve_web.py` 预览；**不启用 GitHub Pages** |
| 说明 | 仅内部；六关完整可玩（Stage 5–6 船舱 / 决战甲板、SMEE / HOOK、鳄鱼结局），通关后回环周目可用 |

## 4.1 首次云端发布记录（V0.0.1）

| 项 | 值 |
|---|---|
| 仓库 | `xinyule/hook`（private，默认分支 `main`） |
| 发布 tag | `v0.0.1` |
| 产物（路线 A 重建后） | `hook3d_v0.0.1_windows_x86_64.zip`、`hook3d_v0.0.1_web.zip` |
| 产物（首次验证时，已废弃） | `IsleReclaimed_v0.0.1_*`（B 包候选名，随路线变更删除） |
| 构建环境 | GitHub Actions `windows-latest` + `ubuntu-latest`，Godot 4.3-stable 编辑器与导出模板在 runner 上现下现用 |
| 门禁 | `node tools/validate_data.js` + 内部限定/产物目录检查 + 版本号格式检查 |
| 工程坑（已修复） | ① Windows GUI 版 exe 在 PowerShell 下不等待 → 改用 `*_console.exe`；② 账号 Actions artifact 配额已满 → 改为 build job 直接 `gh release upload` |
| 说明 | 该 Release 是**工程链路验证产物**，只有引擎启动自检屏，不是可玩游戏；标记为预发布；**私有仓库内仅供内部下载，禁止对外分发，不启用 GitHub Pages** |

## 5. 每阶段收尾清单

- [x] `project.godot` 的 `config/version` 已更新
- [x] 本文件里程碑状态与台账已更新
- [x] `README.md` 当前阶段/版本已更新
- [x] 设计报告附录 C 追加对应记录，并重新生成 HTML
- [x] `node tools/validate_data.js` 通过
- [x] 可运行版本已交付并经确认
