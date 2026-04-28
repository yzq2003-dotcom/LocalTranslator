# 本地模型右键翻译工具 v2 (Local AI Translator)

全面优化版本，主要改进：

| 特性 | v1 | v2 |
|------|----|----|
| **UI** | AppleScript 基础弹窗 | Swift 原生毛玻璃半透明面板 |
| **布局** | 只显示译文 | 原文 + 译文 + 语言方向 + 模型信息 |
| **语言检测** | 无 | 自动检测中/英并确定翻译方向 |
| **qwen3 兼容** | 会输出思考过程 | 自动清除 `<think>` 标签 |
| **加载体验** | 无反馈 | 系统通知提示"翻译中..." |
| **超时时间** | 30s | 60s (适配本地大模型推理) |
| **可选文本** | 不可选 | 译文/原文均可划选复制 |
| **快捷键** | 无 | ⌘C 拷贝 / ESC 关闭 |

---

## 文件清单

| 文件 | 用途 |
|------|------|
| [translate.py](file:///Users/yzq/Desktop/workspace/开发/LocalTranslator/translate.py) | 翻译逻辑主脚本（语言检测 → Ollama 调用 → UI 启动） |
| [TranslatorUI.swift](file:///Users/yzq/Desktop/workspace/开发/LocalTranslator/TranslatorUI.swift) | Swift 原生半透明面板源码 |
| `TranslatorUI` | 编译好的 Swift 二进制 (已就绪) |

---

## 🚀 在系统中启用右键菜单

### 第 1 步：部署运行时文件
先把脚本和 UI 二进制安装到 `~/Library/Application Support/LocalTranslator`。不要让 Automator 直接调用 Desktop 下的脚本，否则 macOS 可能拦截并报 `Operation not permitted`。

```bash
cd "$HOME/Desktop/workspace/开发/LocalTranslator"
./scripts/install_runtime.sh
```

### 第 2 步：打开自动操作
1. 按下 `Command (⌘) + Space` 打开聚焦搜索。
2. 输入 **"自动操作"** 或 **"Automator"**，回车打开。
3. 弹出类型选择窗口时，点击 **"新建文档" (New Document)**。
4. 选择 **"快速操作" (Quick Action)**，点击"选取"。

### 第 3 步：配置选项
在右侧顶部的配置区域，确保按以下方式设置：
- 流程收到当前 **文本 (text)** 
- 位于 **任何应用程序 (any application)**

### 第 4 步：绑定脚本
1. 在左侧的搜索框中输入 **"运行 Shell 脚本"** (Run Shell Script)。
2. 双击或将它拖拽到右侧的空白工作区。
3. 在新出现的框中，进行以下设置：
   - **Shell**: 选 `/bin/bash`
   - **传递输入**: 选择 **"至 stdin" (to stdin)**  👈 *(这一步非常关键)*
4. 在下方的代码框中，清空已有的所有内容，并将以下**完整代码**复制粘贴进去：

```bash
export PYTHONMALLOC=malloc
export LOCALTRANSLATOR_MODEL="gemma4:latest"
/usr/bin/python3 "$HOME/Library/Application Support/LocalTranslator/translate.py"
```

### 第 5 步：保存并使用
1. 按 `Command (⌘) + S` 保存。
2. 命名为 **"🌟 AI 本地翻译"** (或任何您喜欢的名字)。
3. 在任意软件中选中文字，右键 -> **服务** -> **🌟 AI 本地翻译** 即可体验！

> [!TIP]
> **设置快捷键**：前往 **系统设置 > 键盘 > 键盘快捷键 > 服务**，找到您保存的名称并录入快捷键（如 `⌘⇧T`）。

> [!TIP]
> **切换模型**：修改 Automator 脚本里的 `LOCALTRANSLATOR_MODEL`，或直接修改 `translate.py` 中的默认模型。例如改为 `"llama3.2"` 或 `"gemma3:27b"` 等。
