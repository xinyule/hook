# 2.5D 横版清关项目 · M0 骨架（V0.0.1）· 路线 A 仅内部

Godot 4.3 / GL Compatibility / Windows + Web 双平台构建。

> ## ⚠️ 仅内部 · 禁止对外
>
> 用户 2026-11-13 决策变更：**取消 B 原创化路线，改为单轨 A 忠实复刻（仅内部）**。
> 本项目只用于个人学习、本地测试与手感对照，**不得公开发布、上架、商业化、对外分发，不得把仓库转为 public，不得部署到任何公开可访问的站点（含 GitHub Pages）**。
> 原作含 Irem（程序/美术/音乐）与 TriStar Pictures（电影 IP）两层权利；这不是法律意见，如需对外请重新评估并取得授权。

## 当前状态

| 项 | 值 |
|---|---|
| 阶段 | **M0**（决策冻结与事实基线），CI/CD 已打通 |
| 项目版本 | **V0.0.1**（规则与台账见 `VERSION.md`） |
| 内容路线 | **单轨 A 忠实复刻，仅内部**；B 原创化已取消 |
| 引擎 | Godot **4.3-stable**，免安装 ZIP，GL Compatibility |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 可玩内容 | **无**。当前只有引擎启动自检屏，M1 才开始写玩法 |

设计报告、原作动线表、`内容包命名对照表.md`（已归档作废）与 12 张原作参考截图属于**本地事实底稿，不入库**。本仓库只放代码、数据驱动配置、构建流水线与版本台账。

`data/*.json` 目前用稳定 ID 与中性显示名作为**工程标识**；忠实表达层（原作名称、造型、剧情、Boss 名、UI、音频）由唯一内容包 `internal_reference` 在 M1 起填充，不从第三方直接拷贝原作美术/音乐/截图。

## 决策摘要（2026-11-13 冻结，含当日变更）

| 项 | 决定 |
|---|---|
| 内容路线 | **A 忠实复刻，仅内部**（原「B 对外 + A 内测双轨」已取消） |
| 3D 化 | 2.5D 横向卷轴，平面判定 + 实体屏幕边界 |
| 引擎 | Godot 4.x 免安装 ZIP 版 |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 多人 | 一期完整 1–4 人本地合作 |
| 街机规则 | 投币续关 + 无限循环一期保留，按 `RuleSet` 接口可插拔 |

## 快速开始（本机）

1. 用任意 Godot **4.3** 编辑器打开本目录的 `project.godot`（免安装 ZIP 解压即用，不写注册表、不开机常驻）。
2. F5 运行，应看到 M0 骨架自检屏。
3. 数据自检：`node tools/validate_data.js`（校验 14 个 JSON、交叉引用、单轨 A 内部限定、街机规则）。

引擎加载自检：`<godot> --headless --path . --quit`（exit=0 即项目骨架合法）。

## 构建与发布（GitHub Actions，私有 Release）

| 工作流 | 触发 | 作用 |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR 到 `main`、手动 | Node 数据校验；内部限定与产物门禁；版本号格式检查 |
| `.github/workflows/build-release.yml` | `v*` tag、手动 | 先建私有 Release 壳，再分别导出 **Windows x86_64** 与 **Web**，两个 job 直接上传 zip |

`build-release.yml` 在 runner 上自动下载 Godot 4.3 编辑器与导出模板，无需密钥。产物使用内部代号 `hook3d`（**已移除 B 包候选名**）：

- `Windows Desktop` → `build/windows/hook3d.exe`（+ `.pck`）
- `Web` → `build/web/index.html`（+ `.wasm` / `.pck` / `.js`）

发布流程（本机 git 协议不通，实际用 GitHub API 建 tag ref）：

```bash
git tag v0.0.1
git push origin v0.0.1      # 触发 Build & Release，自动创建私有预发布 Release
```

Web 包必须通过 HTTP 提供（本地 `python -m http.server` 或带访问控制的自建服务），`file://` 直接打开会因 CORS 失败。

### 为什么不用 GitHub Pages

技术上完全可行（Web 产物是纯静态文件，推到 `gh-pages` 分支即可），但 **GitHub Pages 站点是公开可访问的**，与「路线 A 仅内部」直接冲突；后续一旦填入忠实内容即构成对外分发。因此本项目**不启用 Pages**，也不写自动部署工作流。可用的内部预览方式：本地 HTTP 服务、自建 nginx + Basic Auth / IP 白名单（项目另有 Debian 12 服务器）、或私有仓库 Release 附件的登录后下载。

## 目录结构

```
.
├── .github/workflows/     ci.yml / build-release.yml
├── project.godot          Godot 4 项目配置（config/version = 0.0.1）
├── export_presets.cfg     Windows / Web 导出预设
├── scenes/                M0 只有 boot.tscn 自检屏
├── data/                  数据驱动配置（角色/敌人/Boss/道具/关卡/规则/内容包）
├── assets/packs/internal_reference/   唯一内容包（M1 起填充自制/重制资产）
├── tools/                 validate_data.js 等校验脚本
├── VERSION.md             版本约定与变更台账
└── README.md
```

## 硬约束

- 所有平衡数值、波次、隐藏点、TIME/飞鹰阈值都写在 `data/`，不硬编码进脚本。
- 四类街机规则只通过 `Game.rules` 取值：`CreditSystem` / `LoopPolicy` / `TimePressure` / `JoinPolicy`。
- **仓库必须保持 private**；`data/packs/pack_manifest.json` 的 `public_release` 恒为 `false`，CI 有门禁，B 包目录不得复现。
- 不把原作截图、原声音乐、原始像素美术等第三方素材提交进仓库；内容包只放自制/重制资产与对照文本。
- 不部署 GitHub Pages 或任何公开站点；Release 产物仅私有仓库协作者可下载。

## 下一步（M1）

1 名角色原型 + 1 类小兵 + 1 段走廊；移动/跳跃/四连段/抓投 5 下自动投出/跳击；基础摄像机与实体屏幕边界；验收 60fps、输入延迟 ≤ 2 帧、贴墙卡位成立。交付后升 **V0.1.0**。
