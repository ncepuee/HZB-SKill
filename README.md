# HZB-Skill

HZB's custom AI agent skills collection for Claude Code, Codex, and other AI coding tools.

当前版本：[v1.0.8](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.8)

## Skills (24 个)

| Skill | 来源/书籍 | 核心内容 |
|-------|----------|---------|
| `multivariable-control` | Multivariable Feedback Control (Skogestad & Postlethwaite) | SVD、RGA、H∞、μ分析、鲁棒控制 |
| `control-beauty-vol1` | 控制之美 第1册 (吴昊) | 传递函数、Bode图、根轨迹、状态空间、PID |
| `control-beauty-vol2` | 控制之美 第2册 (吴昊) | LQR/LQG、MPC、Kalman滤波 |
| `power-system-dynamics-control` | Power System Dynamics (Andersson) | 频率控制、电压控制、FACTS、系统稳定性 |
| `align-ieee-powerflow-simulink` | IEEE标准节点系统 & MATLAB/Simulink SPS | 潮流与Phasor模型参数对齐、初始化、序测量、P/Q及误差验证 |
| `route-simulink-schematics` | 人工优化的IEEE 123节点三相馈线布局 | 拓扑优先布局、三相平行成束布线、模块方向选择、布局差分审计 |
| `simulink-connection-integrity` | 通用 Simulink 接线完整性守卫 | 修改前连接基线、修改后断线/悬空端口/Mask PID/Goto-From/未修改模块差分审计 |
| `dynamic-mode-decomposition` | DMD (Kutz & Brunton) | DMD算法、Koopman算子、数据驱动建模 |
| `Khalil-Nonlinear-Systems-3rd` | Nonlinear Systems 3rd (Khalil) | Lyapunov稳定性、ISS、无源性、反馈线性化、奇异摄动 |
| `Modern-Control-Engineering-Ogata` | Modern Control Engineering 5th (Ogata) | 根轨迹、频域设计、PID整定、状态空间 |
| `PID-Theory-Design-Astrom` | PID Controllers (Åström) | Ziegler-Nichols、Lambda/IMC整定、抗饱和、二自由度 |
| `Robust-Optimal-Control` | Robust and Optimal Control (Zhou, Doyle, Glover) | H∞控制、μ综合、LQG/LTR、模型降阶 |
| `Feedback-Control-Dynamic-Systems` | Feedback Control of Dynamic Systems 7th (Franklin) | 根轨迹设计、频域整形、状态空间、数字控制 |
| `Lewis-Optimal-Control-3rd` | Optimal Control 3rd (Lewis) | Pontryagin原理、LQR/LQG、Bellman方程、MRAC |
| `ieee-figure` | IEEE论文图表规范 | Figure格式、尺寸、字体、颜色 |
| `IEEE-Reference` | IEEE/TIE 参考文献规范 | BibTeX条目、IEEEtranTIE、DOI、标准、专利、引用检查 |
| `openstd-pdf-download` | Open Standards | 从openstd.samr.gov.cn检索并下载国家标准PDF |
| `patent-pdf-download` | Patent PDF Download | 批量下载专利全文PDF，支持CN/US/EP/JP专利，Google Patents API + cnipa.gov.cn 多源回退 |
| `excel-to-pdf` | Excel to PDF | 将Excel签到表/花名册转换为A4可打印PDF（支持中文字体） |
| `multi-agent-comm` | Multi-Agent Communication | 多智能体通信框架、任务委派、跨Agent协同 |
| `scr-calculator` | SCR Calculator | 短路比计算器，支持Lg↔SCR换算、批量对照表、电网强度分类 |
| `academic-ppt-infographic-cn-skill` | 中文学术PPT信息图 | 科技成果鉴定/科技奖申报风格PPT信息图生成、技术路线图、三栏/四层结构 |
| `twitter-auto-publisher` | Twitter/X 自动发布工具 | Chrome CDP 自动调研+发推，无需 Twitter API，支持账号抓取/关键词搜索/微信文章搜索 |
| `pdf-bookmark-migration` | PDF Bookmark Migration | PDF书签（大纲）迁移工具，支持多级嵌套书签、XYZ/Fit目标类型保留、批量处理 |

## Releases

- [v1.0.8](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.8)：新增 `simulink-connection-integrity`，在任意 Simulink 模型修改前后建立连接基线并阻止非预期断线、动态 Mask 端口悬空及未修改模块接线漂移。
- [v1.0.7](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.7)：新增 `pdf-bookmark-migration`，PDF书签迁移工具，支持多级嵌套、XYZ坐标保留、批量处理。
- [v1.0.6](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.6)：新增 `patent-pdf-download`，批量下载专利全文PDF，多源回退策略；更新 `academic-ppt-infographic-cn-skill`。
- [v1.0.5](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.5)：新增 `route-simulink-schematics`，提供拓扑优先的 Simulink/Simscape 布局、三相成束布线与差分审计。
- [v1.0.4](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.4)：新增 `twitter-auto-publisher`，Chrome CDP 自动调研+发推，无需 Twitter API。
- [v1.0.3](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.3)：新增 `academic-ppt-infographic-cn-skill`，中文学术科技奖励PPT信息图生成。
- [v1.0.2](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.2)：新增 `scr-calculator`，短路比计算器，支持Lg↔SCR换算与电网强度分类。
- [v1.0.1](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.1)：版本对齐，发布 `multi-agent-comm` 至 GitHub Releases。
- [v1.0.0](https://github.com/ncepuee/HZB-Skill/releases/tag/v1.0.0)：初始发布，包含 `multi-agent-comm`。

## Usage

```bash
git clone https://github.com/ncepuee/HZB-Skill.git ~/.agents/skills/HZB-Skill
```

## Author

**Zhenbin Huang**

- ORCID: [0000-0002-0628-0387](https://orcid.org/0000-0002-0628-0387)
- LinkedIn: [zhenbin-huang](https://www.linkedin.com/in/zhenbin-huang/)

## License

MIT License - Copyright (c) 2025-2026 Zhenbin Huang
