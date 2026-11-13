# 2.5D 横版清关项目 · M7 美术与音频打磨（V0.7.0）· 路线 A 仅内部

Godot 4.3 / GL Compatibility / Windows + Web 双平台构建。

> ## ⚠️ 仅内部 · 禁止对外
>
> 用户 2026-11-13 决策：**取消 B 原创化路线，改为单轨 A 忠实复刻（仅内部）**。
> 本项目只用于个人学习、本地测试与手感对照，**不得公开发布、上架、商业化、对外分发，不得把仓库转为 public，不得部署到任何公开可访问的站点（含 GitHub Pages）**。
> 原作含 Irem（程序/美术/音乐）与 TriStar Pictures（电影 IP）两层权利；这不是法律意见，如需对外请重新评估并取得授权。

## 当前状态

| 项 | 值 |
|---|---|
| 阶段 | **M7 已交付**（用户授权按 M0→M9 连续推进，不再逐阶段确认） |
| 项目版本 | **V0.7.0**（规则与台账见 `VERSION.md`） |
| 内容路线 | **单轨 A 忠实复刻，仅内部**；B 原创化已取消 |
| 引擎 | Godot **4.3-stable**，免安装 ZIP，GL Compatibility，固定 60 tick |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 可玩内容 | **M2 战斗核心**（五角色 / 七类敌人 / 必杀 / 格挡 / 友伤，全部保留）+ **M3 关卡框架**（StageRunner 六关段落流式加载、WaveDirector 波次生成与同屏上限、1–4P 中途加入与命数/投币续关、TIME 计时 + 飞鹰、计分 + 周目倍率、HUD 全套、LoopManager 周目回环）+ **M4 Stage 1–2 可玩**（码头 / 雪原、BUTCHER / JASON、蜂窝 / 金笼 / 铁球 / 鸡群）+ **M5 Stage 3–4 可玩**（船甲板 / 冰海、假 Hook、DAMON、罐子爆炸、长矛互投、冰柱反跳、企鹅）+ **M6 Stage 5–6 可玩 + 六关通关结局**（船舱 / 船长室 / 决战甲板、SMEE / HOOK、运财小兵 / 炮台、Tinker Bell、鳄鱼结局）+ **M7 表现层打磨**：五角色 / 敌人 / Boss 手绘 Toon 风格化块状模型（分块 + 专属配色 + 描边）、全 VFX（命中火花 / 爆炸 / 财宝爆裂 / 六关天气粒子）、六关光照天气、程序化音频（SFX + 六关自作曲式 BGM，零外部音频文件） |

设计报告、原作动线表、`内容包命名对照表.md`（已归档作废）与 12 张原作参考截图属于**本地事实底稿，不入库**。本仓库只放代码、数据驱动配置、构建流水线与版本台账。

数据表用稳定 ID 作工程标识；忠实表达层由唯一内容包 `internal_reference` 提供，M1 已落地首份映射 `data/packs/internal_reference/names_a.json`（HUD 显示 `PETERPAN` 等对照名），不从第三方拷贝原作美术 / 音乐 / 截图。

## M2 战斗沙盒能玩什么

| 操作 | 键 |
|---|---|
| 左右移动 | `A` / `D` 或 `←` / `→` |
| 攻击（四连段 / 抓投 / 跳击 / 倒地追击） | `J` |
| 跳跃 / 墙跳 | `K` |
| 必杀技（A+B，扣 8% HP） | `J` + `K` 同时按 |
| 重开、退出 | `R`、`Esc` |

- **五角色**：PETERPAN / DON / JOHN / MICHAEL / POCKETS，各有独立招式表（速度、判定、倒地追击上限等差异），启动时选人。
- **四连段**：连按 `J` 四下；第 4 下按得快出 `Special`（16 帧），故意慢按出 `Heavy`（22 帧、击退大）。
- **抓投**：贴身按 `J` 自动抓住，连按 5 下第 5 下**自动投出**；支持**空中投**与**背投**。
- **必杀技**：`J`+`K` 同时按触发，扣 8% 当前 HP，进入必杀状态并有无敌帧；HP 低于 15% 时禁用。
- **落地必杀**：跳跃落地后 6 帧窗口内按必杀触发。
- **倒地追击**：对倒地敌人连打 `J`（默认上限 4 击，POCKETS 为 8）。
- **格挡**：面向攻击来源按防御可减伤至 0.2 倍（部分敌人也能格挡）。
- **友伤**：攻击可伤及队友（含敌间友伤），走 `friendly_fire` 开关。
- **七类敌人**：grunt（三配色）/ drunk / flyer / fatty / spearman / flail / swordsman，各自 AI 由 `enemies.json` 驱动。
- **卡位**：屏幕左右 `x = ±7.6` 是硬边界，把敌人打到右墙可继续连段（原作核心打法的最小验证）。

所有帧数、伤害、速度在 `data/combat_m2.json`、`data/combat_m1.json` 与 `data/balance.json`，代码不硬编码。施工级规格见设计报告 **9.10.11**。

## 快速开始（本机）

1. 用任意 Godot **4.3** 编辑器打开本目录的 `project.godot`（免安装 ZIP 解压即用，不写注册表、不常驻）。
2. F5 运行 → 3D 灰盒走廊 + 角色胶囊 + HUD。
3. 数据自检：`node tools/validate_data.js`（27 个 JSON、交叉引用、单轨 A 内部限定、M1/M2 帧表、街机规则）。
4. 无头逻辑自测（CI 同款，**173 项断言**）：

```bash
# 干净仓库需先让 Godot 建立全局类缓存
<godot> --headless --editor --path . --quit
<godot> --headless --path . -- --selftest     # 输出 SELFTEST PASS，exit=0
```

> headless 下若走正常渲染路径，Godot 的 dummy 渲染后端会打印若干 `mesh_get_surface_count` 噪音；`--selftest` 走纯逻辑模式，零错误。实际窗口运行不受影响。

## 内网运行（用户确认的方式）

不启用 GitHub Pages。Web 包从私有 Release 下载解压到 `build/web`（或本机导出），然后**按需**起服务：

```bash
python tools/serve_web.py --dir build/web --port 8080                     # 仅本机
HOOK3D_WEB_PASSWORD=<口令> python tools/serve_web.py \
    --dir build/web --host 0.0.0.0 --port 8080 --user hook3d              # 内网
```

脚本是纯标准库、不装服务、不开机常驻，`Ctrl+C` 即停；会正确返回 `.wasm` 的 `application/wasm` MIME。绑定 `0.0.0.0` 时不设密码会被**直接拒绝**，避免无认证开放端口。不要把端口映射到公网。

## 构建与发布（GitHub Actions，私有 Release）

| 工作流 | 触发 | 作用 |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR 到 `main`、手动 | Node 数据门禁；单轨 A 内部限定；**Godot headless 173 项自测**；版本号格式 |
| `.github/workflows/build-release.yml` | `v*` tag、手动 | 私有 Release 壳 + Windows x86_64 / Web 双平台导出 + 直接上传 zip |

产物用内部代号 `hook3d`（已移除 B 包候选名）：`build/windows/hook3d.exe`（+ `.pck`）、`build/web/index.html`（+ `.wasm` / `.pck` / `.js`）。本机 git 智能 HTTP 不通，建 tag 实际走 GitHub API：

```bash
git tag v0.1.0 && git push origin v0.1.0     # 触发 Build & Release
```

## 目录结构

```
.
├── .github/workflows/     ci.yml / build-release.yml
├── project.godot          Godot 4 项目配置（config/version = 0.7.0，main_scene = m7.tscn）
├── export_presets.cfg     Windows / Web 导出预设
├── scenes/                m7.tscn（M7 主场景）、m6.tscn（M6 主场景，保留）、m5.tscn（M5 主场景，保留）、m4.tscn（M4 主场景，保留）、m3.tscn（M3 主场景，保留）、m2.tscn（M2 沙盒，保留）、m1.tscn（M1 原型，保留）、boot.tscn（M0 骨架，保留）
├── scripts/m7/            m7_data / m7_visual / m7_vfx / m7_audio / m7_arena
├── scripts/m6/            m6_data / m6_boss / m6_props / m6_stage_scene / m6_arena（M7 复用，不改）
├── scripts/m5/            m5_data / m5_boss / m5_props / m5_stage_scene / m5_arena（M6/M7 复用，不改）
├── scripts/m4/            m4_data / m4_boss / m4_props / m4_stage_scene / m4_arena（M5/M6/M7 复用，不改）
├── scripts/m3/            m3_data / m3_stage_runner / m3_wave_director / m3_player_manager / m3_timer / m3_score / m3_hud / m3_arena（M4/M5/M6/M7 复用，不改）
├── scripts/m2/            m2_data / m2_actor / m2_player / m2_enemy / m2_arena（M3/M4/M5/M6/M7 复用，不改）
├── scripts/m1/            m1_data / m1_actor / m1_player / m1_enemy / m1_arena（保留）
├── data/                  27 个 JSON：角色/敌人/Boss/道具/关卡/规则/内容包/HUD/视觉/VFX/音频
│   ├── combat_m1.json             M1 战斗帧表
│   ├── combat_m2.json             M2 招式与判定帧表
│   ├── enemies.json               七类敌人模板与 AI 参数
│   ├── hud_m3.json                M3 HUD 布局与飞鹰参数
│   ├── bosses_m4.json             M4 BUTCHER / JASON 招式帧表与演出参数
│   ├── props_m4.json              M4 蜂窝 / 铁球 / 鸡群 / 可击碎物件 / 食物配置
│   ├── bosses_m5.json             M5 假 Hook / DAMON 招式帧表与演出参数
│   ├── props_m5.json              M5 假 Hook 互投 / 彩绘大罐 / 长矛 / 冰柱 / 企鹅配置
│   ├── bosses_m6.json             M6 SMEE / HOOK 招式帧表、三阶段阈值与演出参数
│   ├── props_m6.json              M6 运财小兵 / 炮台三连发 / Tinker Bell / 鳄鱼结局配置
│   ├── visual_m7.json             M7 调色板 / Toon 分块 / UI 对齐参数
│   ├── vfx_m7.json                M7 粒子特效与六关天气配置
│   ├── audio_m7.json              M7 程序化 SFX 参数与 BGM 音符表
│   ├── stages/                    六关段落与波次数据（stage_01-06 含 spawn_props / lighting_preset）
│   └── packs/internal_reference/names_a.json   A 包忠实对照名
├── assets/packs/internal_reference/   唯一内容包（后续填充自制/重制资产）
├── tools/                 validate_data.js、serve_web.py
├── VERSION.md             版本约定与变更台账
└── README.md
```

## 硬约束

- 所有平衡数值、波次、隐藏点、TIME/飞鹰阈值都写在 `data/`，不硬编码进脚本。
- 四类街机规则只通过 `Game.rules` 取值：`CreditSystem` / `LoopPolicy` / `TimePressure` / `JoinPolicy`（M3 落地）。
- **仓库必须保持 private**；`data/packs/pack_manifest.json` 的 `public_release` 恒为 `false`，CI 有门禁，B 包目录不得复现。
- 不把原作截图、原声音乐、原始像素美术等第三方素材提交进仓库；内容包只放自制/重制资产与对照文本。
- 不部署 GitHub Pages 或任何公开站点；Release 产物仅私有仓库协作者可下载。

## 下一步（M8，不再等确认）

平衡定稿：数值实测调优、三档难度、辅助选项、隐藏宝藏全点位、贪分 / PK、成就统计、练习模式、最高分。规格见设计报告 **9.10.17** 起，交付后升 **V0.8.0**。
