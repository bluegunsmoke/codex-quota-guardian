# Codex Guardian 1.0.0-rc.7 D 盘迁移审计

审计日期：2026-07-14  
状态：本机测试候选，未发布、未推送、未创建 GitHub Release。

## 最终目录

- 项目源码与全部构建产物：`D:\CodexGuardian\project`
- 已安装应用：`D:\CodexGuardian\runtime\app`
- 本地设置、历史与通知决策：`D:\CodexGuardian\runtime\data`
- 旧 AppData 留档：`D:\CodexGuardian\legacy`
- 用户级配置：`CODEX_GUARDIAN_HOME=D:\CodexGuardian\runtime`

开源默认值仍为 `%USERPROFILE%\.codex-guardian`；设置绝对路径的 `CODEX_GUARDIAN_HOME` 后，应用与 Skill 统一使用 `<home>\app` 和 `<home>\data`。相对路径会被拒绝。

## 迁移完整性

- C 盘项目跨盘移动中断后，采用补齐复制和逐文件验证收口。
- C 盘剩余 7,492 个文件全部在 D 盘找到。
- 缺失文件：0；长度不符：0；SHA-256 不符：0。
- C 盘项目内容已清空；旧根目录本身为 0 字节空目录，因当前 Codex 工作区句柄暂时不能移除。
- `C:\Users\dell\.codex-guardian`、`%LOCALAPPDATA%\CodexGuardian` 和 Codex 包 `LocalCache\Local\CodexGuardian` 均已迁出且未被应用重建。

## 最终门禁

| 门禁 | 证据 |
|---|---|
| D 盘 Release 构建 | 通过：0 警告、0 错误 |
| 单元与契约测试 | 通过：65/65 |
| Skill | 通过：安装、检测、诊断、修复和卸载引导均解析到 D 盘；Windows PowerShell 5.1 兼容 |
| 双语目录 | 通过：172 个资源键、152 个引用、0 个硬编码 XAML 字符串 |
| 隐私与安全 | 通过：应用网络 API 0；Skill 删除命令 0 |
| rc.7 ZIP | `75AB0A3D22826C28A213A09455587C466259B6DBE97A61400FCA7B96F51BE58B` |
| 安装 EXE 同一性 | 安装 EXE 与发布 EXE SHA-256 均为 `E5541726103FED64EBB2F4CBF1F981D7D001320044776626FC31555621C8D1E5` |
| D 盘运行 | 通过：进程路径为 `D:\CodexGuardian\runtime\app\CodexGuardian.App.exe`，单进程且响应正常 |
| D 盘数据 | 通过：历史与通知决策在启动后继续写入 `D:\CodexGuardian\runtime\data` |
| D 盘 bundle cache | 通过：实际启动后 774 个解压文件、296,874,073 字节全部写入 `D:\CodexGuardian\runtime\bundle-cache` |
| C 盘回写 | 通过：旧运行数据、测试 Temp、`.net\CodexGuardian.App`、CrashDumps 与 Codex 包缓存均无 Guardian 残留；用户目录名称扫描匹配为 0 |

## 最终残留收口

- 迁移并校验 6,192 个 `.NET` 单文件缓存文件（约 2.37 GB）、10 个测试临时文件、5 个崩溃转储和 1 个最近访问快捷方式。
- 用户级 `DOTNET_BUNDLE_EXTRACT_BASE_DIR` 已固定为 `D:\CodexGuardian\runtime\bundle-cache`；Skill 安装器启动应用时也显式注入该路径。
- 测试夹具不再使用系统 `%TEMP%`，默认写入 D 盘测试程序集旁的 `test-temp`；调整后重新运行 65/65 通过，C 盘测试目录未重建。
- C 盘旧项目根目录仍是 0 内容空目录，仅因当前 Codex 工作区句柄占用暂不能移除，不占用项目文件空间。
- 迁移完成后的 C 盘可用空间为约 12.33 GB。

## 结论

rc.7 已完成 D 盘迁移并保持开源候选标准。当前继续等待维护者按 `docs/local-test-checklist.md` 完成本机体验门禁。
