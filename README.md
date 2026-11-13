# 2.5D 横版清关项目 · M0 骨架（V0.0.1）

Godot 4.3 / GL Compatibility / Windows + Web 双平台构建。

> **仓库名 `hook` 与本地目录名 `hook3d` 都只是内部代号。** 导出产物名、窗口标题、包名、对外物料一律不得使用内部代号或任何原作名称，必须取自 B 内容包的定稿名；当前 `Isle Reclaimed / IsleReclaimed` 是 M0 临时占位，定稿前不得对外发布。

## 当前状态

| 项 | 值 |
|---|---|
| 阶段 | **M0**（决策冻结与事实基线），CI/CD 已打通 |
| 项目版本 | **V0.0.1**（规则与台账见 `VERSION.md`） |
| 引擎 | Godot **4.3-stable**，免安装 ZIP，GL Compatibility |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 可玩内容 | **无**。当前只有引擎启动自检屏，M1 才开始写玩法 |

设计报告、原作动线表、内容包命名对照表、原作参考截图属于**本地事实底稿，不入库**（含版权分析素材，避免进入任何对外物料）。本仓库只放代码、数据驱动配置、构建流水线与版本台账。

## 决策摘要（2026-11-13 冻结）

| 项 | 决定 |
|---|---|
| 内容路线 | B 原创化对外 + A 忠实版内测，双轨（同一套代码，两套内容包） |
| 3D 化 | 2.5D 横向卷轴，平面判定 + 实体屏幕边界 |
| 引擎 | Godot 4.x 免安装 ZIP 版 |
| 一期平台 | Windows 桌面 + Web；Android 后置 |
| 多人 | 一期完整 1–4 人本地合作 |
| 街机规则 | 投币续关 + 无限循环一期保留，按 `RuleSet` 接口可插拔 |

## 快速开始（本机）

1. 用任意 Godot **4.3** 编辑器打开本目录的 `project.godot`（免安装 ZIP 解压即用，不写注册表、不开机常驻）。
2. F5 运行，应看到 M0 骨架自检屏。
3. 数据自检：`node tools/validate_data.js`（校验 14 个 JSON、交叉引用、内容包策略、街机规则、IP 禁词）。

引擎加载自检：`<godot> --headless --path . --quit`（exit=0 即项目骨架合法）。

## 构建与发布（GitHub Actions）

| 工作流 | 触发 | 作用 |
|---|---|---|
| `.github/workflows/ci.yml` | push / PR 到 `main`、手动 | Node 数据校验；内容包与产物门禁；版本号格式检查 |
| `.github/workflows/build-release.yml` | `v*` tag、手动 | 分别导出 **Windows x86_64** 与 **Web** 包，打成 zip 并上传到 GitHub Release |

`build-release.yml` 会在 runner 上自动下载 Godot 4.3 编辑器与导出模板，无需任何密钥或不入库的私有资源。两个导出目标定义在 `export_presets.cfg`：

- `Windows Desktop` → `build/windows/IsleReclaimed.exe`（+ `.pck`）
- `Web` → `build/web/index.html`（+ `.wasm` / `.pck` / `.js`）

发布流程：

```bash
git tag v0.0.1
git push origin v0.0.1      # 触发 Build & Release，自动创建预发布 Release
```

Web 包必须通过 HTTP 提供（例如静态站点或 `python -m http.server`），直接双击 `index.html` 用 `file://` 打开会因浏览器 CORS 限制失败。

## 目录结构

```
.
├── .github/workflows/     ci.yml / build-release.yml
├── project.godot          Godot 4 项目配置（config/version = 0.0.1）
├── export_presets.cfg     Windows / Web 导出预设
├── scenes/                M0 只有 boot.tscn 自检屏
├── data/                  数据驱动配置（角色/敌人/Boss/道具/关卡/规则/内容包）
├── assets/                M1 起填充；packs/public 对外，packs/internal_reference 永不入库
├── tools/                 validate_data.js 等校验脚本
├── VERSION.md             版本约定与变更台账
└── README.md
```

## 硬约束

- 所有平衡数值、波次、隐藏点、TIME/飞鹰阈值都写在 `data/`，不硬编码进脚本。
- 四类街机规则只通过 `Game.rules` 取值：`CreditSystem` / `LoopPolicy` / `TimePressure` / `JoinPolicy`。
- `assets/packs/internal_reference/` 绝不入仓库、绝不进导出产物；CI 有目录门禁，M9 还有产物扫描门禁。
- 不使用原作音乐、音效、截图、像素素材；`data/` 有 IP 禁词校验。
- **本仓库当前为私有开发仓**。转公开前必须完成：B 包名称定稿、全仓与全部产物合规扫描、报告 M9 发布门禁。

## 下一步（M1）

1 名角色原型 + 1 类小兵 + 1 段走廊；移动/跳跃/四连段/抓投 5 下自动投出/跳击；基础摄像机与实体屏幕边界；验收 60fps、输入延迟 ≤ 2 帧、贴墙卡位成立。交付后升 **V0.1.0**。
