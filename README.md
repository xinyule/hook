# 2.5D 横版清关项目 · M1 可玩原型（V0.1.0）· 路线 A 仅内部

Godot 4.3 / GL Compatibility / Windows + Web 双平台构建。

> ## ⚠️ 仅内部 · 禁止对外
>
> 用户 2026-11-13 决策：**取消 B 原创化路线，改为单轨 A 忠实复刻（仅内部）**。
> 本项目只用于个人学习、本地测试与手感对照，**不得公开发布、上架、商业化、对外分发，不得把仓库转为 public，不得部署到任何公开可访问的站点（含 GitHub Pages）**。
> 原作含 Irem（程序/美术/音乐）与 TriStar Pictures（电影 IP）两层权利；这不是法律意见，如需对外请重新评估并取得授权。

## 当前状态

| 项 | 值 |
|---|---|
| 阶段 | **M1 已交付**（用户授权按 M0→M9 连续推进，不再逐阶段确认） |
| 项目版本 | **V0.1.0**（规则与台账见 `VERSION.md`） |
| 内容路线 | **单轨 A 忠实复刻，仅内部**；B 原创化已取消 |
| 引擎 | Godot **4.3-stable**，免安装 ZIP，GL Compatibility，固定 60 tick |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 可玩内容 | 1 名角色 + 1 类杂兵 + 1 段 16m 走廊；移动 / 跳跃 / 四连段（快慢分支）/ 抓投 5 下自动投出 / 跳击；正交相机、实体屏幕边界、HUD |

设计报告、原作动线表、`内容包命名对照表.md`（已归档作废）与 12 张原作参考截图属于**本地事实底稿，不入库**。本仓库只放代码、数据驱动配置、构建流水线与版本台账。

数据表用稳定 ID 作工程标识；忠实表达层由唯一内容包 `internal_reference` 提供，M1 已落地首份映射 `data/packs/internal_reference/names_a.json`（HUD 显示 `PETERPAN` 等对照名），不从第三方拷贝原作美术 / 音乐 / 截图。

## M1 能玩什么

| 操作 | 键 |
|---|---|
| 左右移动 | `A` / `D` 或 `←` / `→` |
| 攻击（四连段 / 贴身抓投 / 跳击） | `J` |
| 跳跃 | `K` |
| 重开、退出 | `R`、`Esc` |

- **四连段**：连按 `J` 四下；第 4 下按得快出 `Special`（16 帧），故意慢按出 `Heavy`（22 帧、击退大）。
- **抓投**：贴身按 `J` 自动抓住，连按 5 下第 5 下**自动投出**，敌人抛物线飞出、撞墙反弹一次后倒地。
- **跳击**：`K` 起跳后按 `J`。
- **卡位**：走廊左右 `x = ±7.6` 是硬边界，把敌人打到右墙可继续连段（原作核心打法的最小验证）。
- 三个 `grunt` 配色变体（白蓝 / 蓝白 / 绿红），共享 AI：接近 → 6 帧抬手预兆 → 4 帧匕首攻击 → 20 帧收招后退；20 HP，`hero_01` 三下轻击可杀。

所有帧数、伤害、速度在 `data/combat_m1.json` 与 `data/balance.json`，代码不硬编码。施工级规格见设计报告 **9.10**。

## 快速开始（本机）

1. 用任意 Godot **4.3** 编辑器打开本目录的 `project.godot`（免安装 ZIP 解压即用，不写注册表、不常驻）。
2. F5 运行 → 3D 灰盒走廊 + 角色胶囊 + HUD。
3. 数据自检：`node tools/validate_data.js`（16 个 JSON、交叉引用、单轨 A 内部限定、M1 帧表、街机规则）。
4. 无头逻辑自测（CI 同款，26 项断言）：

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
| `.github/workflows/ci.yml` | push / PR 到 `main`、手动 | Node 数据门禁；单轨 A 内部限定；**Godot headless 26 项自测**；版本号格式 |
| `.github/workflows/build-release.yml` | `v*` tag、手动 | 私有 Release 壳 + Windows x86_64 / Web 双平台导出 + 直接上传 zip |

产物用内部代号 `hook3d`（已移除 B 包候选名）：`build/windows/hook3d.exe`（+ `.pck`）、`build/web/index.html`（+ `.wasm` / `.pck` / `.js`）。本机 git 智能 HTTP 不通，建 tag 实际走 GitHub API：

```bash
git tag v0.1.0 && git push origin v0.1.0     # 触发 Build & Release
```

## 目录结构

```
.
├── .github/workflows/     ci.yml / build-release.yml
├── project.godot          Godot 4 项目配置（config/version = 0.1.0，main_scene = m1.tscn）
├── export_presets.cfg     Windows / Web 导出预设
├── scenes/                m1.tscn（M1 主场景）、boot.tscn（M0 骨架，保留）
├── scripts/m1/            m1_data / m1_actor / m1_player / m1_enemy / m1_arena
├── data/                  16 个 JSON：角色/敌人/Boss/道具/关卡/规则/内容包
│   ├── combat_m1.json             M1 战斗帧表
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

## 下一步（M2，不再等确认）

五角色 REACH/POWER/SPEED 差异与选人界面、七类杂兵与配色变体、必杀 / 临落地绝招 / 踩墙二段跳 / 空投 / 倒地追击、Hitbox 资源化与友伤格挡。规格见设计报告 **9.10.11**，交付后升 **V0.2.0**。
