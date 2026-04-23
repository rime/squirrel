# flypy-rime-config 目录说明

本目录用于保存小鹤音形配置的参考文件，作为项目内置配置的来源之一。

## 目录定位

- 保存 flypy 相关的 `*.yaml`、`*.txt`、`rime.lua` 等配置与词表文件。
- 这些文件用于打包前的配置同步，不直接作为最终运行时写入目录。
- 该目录应视为“参考源”，不要在构建产物目录里手工改同名文件。

## 与构建流程的关系

- 构建时会将本目录中的配置同步到 `data/plum/`（或 staging 后再同步）。
- `package/add_data_files` 会扫描 `data/plum/*`，并将文件加入 Xcode 的 `Copy Shared Support Files` 阶段。
- 打包后文件进入 `SquirrelFlypy.app/Contents/SharedSupport`。
- 安装阶段 `scripts/postinstall` 会将 `SharedSupport/flypy-rime-config` 下的文件覆盖到用户目录 `~/Library/Rime Flypy`。

## 更新建议

- 更新小鹤配置时，优先在本目录替换源文件，再执行构建/打包流程验证。
- 若新增或删除文件，需同步检查 `data/plum` 接入与工程资源引用是否正确。
- 变更后至少验证一次 `--build` 部署成功，确保 schema 可编译。

## 注意事项

- 请勿将临时文件、系统生成文件（如 `.DS_Store`）作为正式配置提交。
- 对于暂缓功能（如 `flypydz` 相关裁剪策略），以 `docs/flypy-optional-features-deferred.md` 为准。
