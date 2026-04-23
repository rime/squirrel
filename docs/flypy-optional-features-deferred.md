# 小鹤音形：当前精简版中暂缓的可选功能

`flypy-rime-config/` 目录中的文件作为**官方/上游配置的只读参考**，在构建时不要直接修改。  
当前 M2 精简接入在**构建 staging** 中做了与下列功能相关的裁剪，以便后续按顺序补回。

## 1. 计算器 translator

- **作用**：通过 Lua 翻译器处理表达式输入（常见为以 `=` 开头的计算或相关模式）。
- **与上游参考的关联**（在 `flypy-rime-config/rime/flypy.schema.yaml` 中仍可查到）：
  - `engine/translators` 中的 `lua_translator@calculator_translator`
  - `recognizer/patterns/expression` 中与 `=` 相关的匹配（例如 `^(=.*|ok[a-z']*)$` 中的 `=.`* 部分是否单独服务于计算器，需与 ok 引导模式一并核对）
- **补回时需检查**：
  - `rime.lua` 中是否提供 `calculator_translator` 实现（当前参考树中仅有日期/时间 Lua 示例）。
  - `librime-lua` 是否已随发行构建启用（否则 Lua translator 不会生效）。

## 2. 二重简码（flypydz）

- **作用**：独立 `flypydz` 方案及相关反查/辅助能力。
- **参考文件**（仍保留在 `flypy-rime-config/rime/`，仅**不打入** `data/plum` 产物）：
  - `flypydz.schema.yaml`
  - `flypydz.dict.yaml`
- **主方案中的关联点**（参考 `flypy.schema.yaml`）：
  - `schema/dependencies` 中的 `flypydz`
  - `reverse_lookup` 段（`dictionary: flypydz`）
  - `engine/translators` 中的 `reverse_lookup_translator`
- **补回顺序建议**：先恢复 `flypydz` 词库与方案文件进入打包目录，再恢复 `flypy.schema.yaml` 中上述段落，最后验证反查与方案依赖编译无误。

## 3. 全码字字典（custom_phraseQMZ / 主码表）

- **作用**：全码相关词条或短语表（在参考 `flypy.schema.yaml` 中表现为 `table_translator@custom_phraseQMZ`；通常还需对应的 `custom_phraseQMZ:` 配置段及词库文件）。
- **当前状态说明**：
  - 参考 `flypy.schema.yaml` 中仍列出 `table_translator@custom_phraseQMZ`，但未附带同名 `custom_phraseQMZ:` 段落；构建 staging 会**移除该 translator 行**以免部署阶段引用缺失配置。
  - 若上游完整包中包含主码表 `flypy.dict.yaml`（或等价命名），本仓库参考树中可能已省略；`rime/build/` 下的 `flypy.*.bin` 为预编译产物，可作为对照，但长期仍应以可重建的 `*.dict.yaml` 源文件为准。
- **补回时需准备**：
  - `custom_phraseQMZ` 的 YAML 配置段与对应用户词典/码表文件；
  - 或恢复完整 `flypy.dict.yaml`（及依赖的 opencc/encoder 等配置），并确认 `translator/dictionary: flypy` 能由源码完整重建。

## 4. 快速加词弹窗扩展功能（M3 后续）

- **范围说明**：以下能力在 M3 基础“快速加词”可用后，再按优先级逐步补齐。
- **扩展项清单**：
  - “将新添加词条固项”勾选框。
  - “剪贴板造词”勾选框。
  - 自动读取最近输入的两个字作为“词条”默认值。
  - 自动查询首选字词字典中对应编码作为“编码”默认值。
  - 支持上下方向键调整自动读取字的长度。
- **实现备注**：
  - 默认写入目标与“固项”逻辑需要与 `flypy_user.txt` / `flypy_top.txt` 写入策略联动定义。
  - “最近输入字串”与“默认编码推断”依赖运行时输入上下文与词典查询接口，建议单独评估可用 API 与失败兜底。

## 构建行为说明（避免误改参考目录）

- 构建时使用 `scripts/stage-flypy-for-data-plum.sh`：从 `flypy-rime-config/rime` 复制到 `build/flypy-staged`，在 staging 中应用补丁后再同步到 `data/plum/`。
- 功能开发全部结束后，可按计划删除 `flypy-rime-config/`；删除前请确认上述可选能力已在正式配置与文档中有替代说明或已合并入主配置树。