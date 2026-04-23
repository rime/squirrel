# 项目结构梳理（M1）

本文档用于记录当前仓库结构与改造边界，作为后续小鹤音形功能开发的基线。

## 项目定位

- 本项目基于 `rime/squirrel`（macOS 前端）与 `rime/librime`（输入引擎）进行二次开发。
- 当前目标是构建专注小鹤音形体验的 macOS 输入法发行版。
- 在未被功能需求阻塞前，优先通过 `schema/dict/deploy` 层改造，不改动核心引擎算法。

## 顶层目录与职责

- `sources`：Squirrel 前端代码（按键处理、候选窗口、上屏逻辑、与 Rime API 交互）。
- `librime/src/rime`：Rime 引擎核心（processor、segmentor、translator、dict、config、deployment）。
- `data`：内置配置资源（如默认前端配置）。
- `plum`：方案与词库安装管理（配方、包安装脚本、部署前资源准备）。
- `scripts`：安装与部署辅助脚本（含 postinstall 等流程入口）。
- `package`：打包相关资源与流程文件。
- `resources`、`Assets.xcassets`、`Rime.icon`：应用资源文件。
- `Squirrel.xcodeproj`：Xcode 工程文件。

## 关键链路

### 1) 输入链路（运行时）

`sources/SquirrelInputController.swift` -> `librime` 引擎处理 -> 候选更新 -> 上屏提交

### 2) 配置链路（方案）

`schema/dict/custom` YAML 资源 -> `rime_deployer` 编译 -> 运行时加载

### 3) 打包与安装链路

`make` / `make package` -> `scripts/postinstall` -> `Squirrel --build` 部署

## M1 产出范围

- 完成项目结构梳理并固化为本文件。
- 更新项目说明文档，明确“基于原项目改造的小鹤音形定位”。

## 后续阶段接口

- M2：仅做小鹤音形配置文件内置接入（不做配置细化）。
- M3：按指定参考仓库实现快速加词。
- M4：从零实现词库管理能力。