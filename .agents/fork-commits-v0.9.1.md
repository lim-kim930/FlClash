# v0.9.1 fork 提交整理记录

基线：`v0.9.1` / `8d4f9744948751f1273fe871e1d05276fac09b0e`。
原始开发快照：`dev` / `8198f2a8fde1e0a66624de4b3de8b6f8c493be2e`，已包含于 `v100.0.12`。
整理分支：`curate/v0.9.1`。原 `dev`、`release` 和发布标签保留。

按最终有效内容迁移，将测试、同步适配和 fixup 拆回功能。按用户补充，agent-assisted 提交允许且需要署名。
本次新提交均包含 `Co-Authored-By: Codex <noreply@openai.com>`。

## 新提交

| 编号 | 新 commit | 实际标题 |
|---|---|---|
| C1 | d4063065 | chore(app): align fork links and about page |
| C2 | 07b02d08 | ci(release): validate and publish fork releases |
| C3 | bb3de2b0 | feat(records): clear request and DNS history |
| C4 | ab7dfb04 | feat(connections): keep connection details live and accurate |
| C5 | 99aa410a | feat(connections): share sorting between settings and table |
| C6 | 701bf149 | fix(geo): synchronize resource settings without profile reloads |
| C7 | 980183ce | fix(tun): recover helper startup and privilege handoffs |
| C8 | d65ed708 | feat(routing): add domain and IP routing lookup |
| C9 | this document's commit | chore(agents): consolidate fork workflow and allow attribution |

Core 独立分支为 `lim-kim930/Clash.Meta:curate/v0.9.1-routing`。
以 v0.9.1 固定的 `8380d0e7462f061a964323e9bf3129a236fcc5d5` 为基线，整理为一个提交：
`a642db35031262f258f1e3b15244943ffbb88893`，包含原 `b4163890` 的查询 API 与锁修复。
父仓库固定 gitlink 前已推送，CI 可获取。

## 原始 36 个提交逐项去向

合并指保留最终有效内容，不表示原 patch 可脱离上下文直接删除或 revert。

| 原 commit | 原标题 | 新位置 | 处理及原因 |
|---|---|---|---|
| 592ddbb5 | feat(requests): add clear button to requests view | C3 | 保留请求清空；补立即清空页面缓存和单调 revision。 |
| 185735c0 | feat(connection): add real-time upload and download speeds to details | C4、C5 | 拆分实时详情与排序；替换父列表监听及重复比较算法。 |
| f4876fe2 | fix(geo): reapply the profile after a geo resource url change | C6 | 删除完整重载 profile 的旧方案，功能目标由轻量同步接替。 |
| d439d53b | chore(ci): disable upstream-only publishing for fork | C2 | 保留 fork 仓库适配和移除上游专属发布。 |
| 2175d171 | ci(build): validate android signing inputs early and stop fail-fast cancels | C2 | 保留签名提前校验和关闭矩阵 fail-fast。 |
| bf7c232d | chore(app): retarget update checks and repository to fork | C1 | 保留更新检查与项目地址指向 fork。 |
| 0c528c0c | fix(release-notes): bound the commit range to this fork's own latest release | C2 | 保留定位 fork 上次发布，与 patch-id 去重合并。 |
| a94be127 | feat(release-notes): group notes by conventional commit type | C2 | 保留发布说明分类及测试，将测试接入 CI。 |
| 4a5a4f51 | fix(release-notes): bound the range by patch id, not by ancestry | C2 | 保留 rebase 后用 patch-id 排除已发布补丁。 |
| ffb6d790 | fix(permission): stop the location request from looping the app lifecycle | 丢弃 | 实际只有轮询状态改动，已被 8198f2a8 完全还原，没有最终净效果。 |
| 9887399b | fix(tun): recover from a failed Windows helper authorization | C7 | 保留 Helper 等待；删除把 unauthorized 当永久失败的旧探测。 |
| b44b0e35 | docs(agents): record the fork's upstream tracking and re-sync rules | C9 | 保留 upstream/main 跟踪和正确 rebase 范围。 |
| 91f544b7 | chore(about): remove community and contributor links | C1 | 保留关于页精简，删除闲置头像和资源声明。 |
| 251e23e8 | fix(tun): restart the Core when helper privileges arrive late | C7 | 保留真实 owner 检查，修复防重入范围和重复重启。 |
| 4126795c | test: add coverage for connection live details, clear requests, and tied sort | C3、C4、C5 | 测试拆回所属功能；旧排序算法测试随实现删除，改验共用排序。 |
| 0912e279 | fix(geo): apply resource settings without a subscription | C6 | 保留无订阅 Geo 配置和同步失败阻断。 |
| eb169b16 | docs(agents): document release branch workflow and clean upstream re-sync | C9 | 保留 dev/release 分工、数字版本及 beta 标签规则。 |
| 9a100c96 | docs(agents): prohibit local packaging and testing | C9 | 保留本地禁止构建和测试，集中在 AGENTS.md。 |
| 466c58fa | fix(sync): adapt fork features to upstream v0.8.99 | C4、C5 | 不保留独立 v0.8.99 同步提交，最终适配拆回功能。 |
| 3ee552c7 | ci(build): enable fork checks and tag releases after upstream sync | C2 | 保留 fork 检查和发布依赖，补全 beta 发布。 |
| 04234492 | test(requests): wait for the upstream render throttle window | C3 | 合并节流适配，补上清空后立即到达新请求的情况。 |
| 6231cd3a | feat(routing): add domain and IP routing lookup | C8、Core | 保留完整路由查询，Core 同时修复递归读锁。 |
| 58cdd893 | test(routing): scroll query results into view before assertions | C8 | 合并路由结果滚动测试适配。 |
| 498b23af | refactor(geo): replace full profile reloads with lightweight config updates | C6 | 作为最终 Geo 轻量同步基础，保留串行调度及结果反馈。 |
| 4f8ac384 | fix(routing,ui): clarify lookup ports and improve network record controls | C3、C8 | DNS 清空归 C3，查询端口、参数说明和结果归 C8。 |
| 54022f02 | docs(agents): document core fork maintenance and allow agent attribution | C9 | 保留 Core fork 维护；按用户补充允许且实际署名，同步钩子。 |
| 5cb49f0c | test(ui): initialize lookup dialog size and await DNS list transitions | C3、C8 | 按 DNS 和路由分别合并尺寸、异步过渡测试修正。 |
| d091bbf6 | docs(agents): require remote release CI to pass before tagging | C9 | 删除已撤销的等待分支 CI 要求，保留有效发布步骤。 |
| c2700d1b | fix(windows): skip helper startup wait when elevation is required | C7 | 保留不兼容分类、Windows 服务查询和有条件等待。 |
| f7dd45c4 | style(ui): redesign route lookup view to match Material You aesthetic | C8 | 仅保留最终界面仍使用的样式，删除中间表单。 |
| 52d4b040 | fix(ui): wrap network type tile in Material to preserve ink splashes | C8，旧实现删除 | 旧网络行已被最终设置行替代，不保留独立 Material 补丁。 |
| 264801cb | fix(ui): group routing lookup fields into settings sections | C8 | 作为最终分组设置界面基础。 |
| 73e99d61 | fixup! fix(ui): group routing lookup fields into settings sections | C8 | 合并对应 UI 测试 fixup。 |
| c33943f8 | docs(agents): allow release tags without waiting for branch CI | C9 | 保留由标签 CI 检查后发布的最终规则。 |
| c030503d | fix(sync): adapt fork features to upstream v0.9.1 | C3～C8 | API、控件、本地化、协议及测试适配拆回各功能，不保留独立同步提交。 |
| 8198f2a8 | fixup! fix(sync): adapt fork features to upstream v0.9.1 | C4、C5、C6、C8 | 合并有效修正，丢弃已经还原的轮询改动。 |

## 每组的代码收敛、修复和验证

### C1：fork 身份与关于页

保留 fork 更新检查和项目地址；删除 Contributor 类型、社区入口、头像资源及失效的本地化键。
关于页 Core 链接随 C8 更新为实际新分支。pubspec 版本号保留 v0.9.1 基线值。

### C2：发布

保留签名提前检查、矩阵独立完成、仓库限制、检查门槛及发布说明分类和 patch-id 范围。
移除 Telegram、Homebrew、F-Droid 发布和 fork 不维护的上游 changelog 校验。
修复 beta 被 Release 条件跳过：beta 设置 prerelease，两类发布都生成校验和。
模板分开使用标签版本与数字包版本，校验两者一致性，避免 beta 文件下载链接失效。
发布说明和模板渲染测试显式接入 CI；负向断言使用明确失败分支。本地仅检查 shell 语法。

### C3：请求与 DNS 清空

同时清空 provider 和页面缓存，避免暂停滚动时保留旧记录。
FixedList.cleared 创建独立空缓冲并递增 revision，避免新记录立即到来时与旧版本号碰撞漏通知。
删除清空前复制整个旧缓冲的操作。回归用例涵盖暂停、清空、节流窗口内新请求、后续继续接收。

CI 首轮发现新用例过早检查渐隐中的旧内容；保留过渡结束后的断言和清空后立即到达的新请求。

### C4：实时连接详情

删除 ValueNotifier<TrackerInfosState> 在列表、行和详情之间逐层传递的方案。
列表负责导航并暂停自身轮询，可见详情负责刷新，返回时在 finally 中恢复列表。
复用 TrackerSpeedRanker 计算速率；连接结束保留最后总量，速率归零并停止轮询。
删除 firstWhere 的旧 orElse 快照回退，避免总量倒退。
回归用例覆盖普通/嵌套弹层、单一轮询、返回恢复、读取失败后重试和连接结束。

### C5：连接排序

设置和表头共用 RecordSort 控制器及上游 RecordSorter，窄屏沿用相同状态，默认值恢复原列表顺序。
不迁入 ConnectionsSortType、SortDirection、模型排序字段、重复 switch 及对应生成改动。
相同键使用上游稳定顺序，不再维护 fork 的二次 ID 排序，旧算法专属测试一并删除。
设置选项由既有表格列生成，保留进程、目标、网络、规则、出口、速率、总量、时长等能力。
测试覆盖设置与表头互通、两种弹层布局、切换窄屏以及恢复默认。

排序菜单以当前选项定位；用例先滚动到目标项再点击，验证真实可点击的设置交互。

### C6：Geo 配置

删除编辑 URL 后完整重载 profile 的旧路径，改用上游轻量配置监听。
手动下载等待串行配置同步，失败不下载，保留修改后 URL 供重试。
保留无订阅基础配置、默认 URL 合并、摘要、持久化恢复、同步期间进度预留。
updateConfig 返回实际结果，在调度任务外交给 Core 重启，避免等待自身调度器。
保留 Dart 的同步/失败/重试/重启/删除最后订阅覆盖，以及 Go 实际下载 fixture。

### C7：Helper 与 TUN

保留四类 readiness、Windows SCM 状态查询和有条件等待；SCM 查询放在 isolate。
缺失或不兼容服务直接请求安装，暂未就绪服务保留启动及崩溃恢复等待。
以桌面 lifecycle 的真实 owner 判断交接，provider 不成为进程所有者。
删除 hasCorePrivilege 探测及 unauthorized 作为持久失败状态的旧分支；授权异常清理 pending 状态。
交接防重入限定为当前恢复过程，交接后仍是 direct Core 时明确失败、关闭 TUN 并允许用户重试。
CoreAction 暴露现有 restart operation 是否活跃，避免授权路径等待自己所在的重启操作。
测试增加跨会话恢复、有界失败、显式重试、异常清理和重启重入。

### C8：路由查询及 Core

保留域名/IP、源/目标端口、TCP/UDP、当前模式、规则、策略、代理链及目标 IP。
保留最终分组界面、七语言、参数校验、加载/失败/未连接状态、协议及 widget 测试。
删除中间文本表单、旧网络行 Material 补丁及独立 UI fixup。
Core 分开自行加锁的入口和调用方已持锁的内部路径；查询全程保留配置读锁，不再递归获取。
并发用例等待 writer 排队后调用已持锁匹配；父仓库 Go CI 显式运行 tunnel 包测试。
gitlink、.gitmodules、Core 链接与维护说明指向新分支。

### C9：维护规则与署名

集中保留 upstream/main、dev/release、beta 版本、Core gitlink、rerere 与验证规则。
删除重复同步章节和已撤销的发布前等待分支 CI 要求。本地构建/测试禁令集中到 AGENTS.md。
按用户要求允许且实际署名：删除钩子的 agent 拒绝分支，测试改验可接受署名。
人类独立工作无需虚构 agent 参与；上游 commands 和技能文件不再重复修改。

## 验证边界

执行必要的本地化和 provider 代码生成，生成文件不手工修改。
本地只做格式、语法及 Flutter 静态分析，没有运行 flutter/dart/go/cargo 或 shell 自动测试，没有启动 app 或打包。
Core 本地检查限于 gofmt 解析与格式；运行测试、覆盖率和多平台构建由远端 CI 判断。
新增测试及本地静态分析通过不等同于远端测试通过，以整理分支实际工作流结果为准。
