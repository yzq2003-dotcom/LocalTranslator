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

### 第 1 步：打开自动操作
1. 按下 `Command (⌘) + Space` 打开聚焦搜索。
2. 输入 **"自动操作"** 或 **"Automator"**，回车打开。
3. 弹出类型选择窗口时，点击 **"新建文档" (New Document)**。
4. 选择 **"快速操作" (Quick Action)**，点击"选取"。

### 第 2 步：配置选项
在右侧顶部的配置区域，确保按以下方式设置：
- 流程收到当前 **文本 (text)** 
- 位于 **任何应用程序 (any application)**

### 第 3 步：绑定脚本
1. 在左侧的搜索框中输入 **"运行 Shell 脚本"** (Run Shell Script)。
2. 双击或将它拖拽到右侧的空白工作区。
3. 在新出现的框中，进行以下设置：
   - **Shell**: 选 `/bin/bash`
   - **传递输入**: 选择 **"至 stdin" (to stdin)**  👈 *(这一步非常关键)*
4. 在下方的代码框中，清空已有的所有内容，并将以下**完整代码**复制粘贴进去：

```bash
export PYTHONMALLOC=malloc
INPUT=$(cat)

/usr/bin/python3 - "$INPUT" << 'PYEOF'
import sys, json, re, os, urllib.request, urllib.error, subprocess

# ⚙️ 配置 —— 换模型改这一行即可
MODEL_NAME = "qwen3.5:9b"
OLLAMA_API_URL = "http://localhost:11434/api/chat"
TIMEOUT = 60
UI_BINARY = os.path.expanduser("~/Desktop/workspace/开发/LocalTranslator/TranslatorUI")

def detect_lang(text):
    cjk = sum(1 for c in text if '\u4e00' <= c <= '\u9fff' or '\u3400' <= c <= '\u4dbf')
    if cjk / max(len(text), 1) > 0.15:
        return "中文", "English", "中文", "English"
    return "英文", "Chinese", "English", "中文"

def clean(text):
    text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    return text if text else "[模型未返回翻译内容]"

def translate(text, target):
    prompt = f"Translate the following text into {target}. Output ONLY the translation.\n\n{text}"
    data = {"model": MODEL_NAME, "messages": [{"role": "user", "content": prompt}], "stream": False}
    req = urllib.request.Request(OLLAMA_API_URL, data=json.dumps(data).encode("utf-8"))
    req.add_header("Content-Type", "application/json")
    try:
        resp = urllib.request.urlopen(req, timeout=TIMEOUT)
        raw = json.loads(resp.read().decode("utf-8")).get("message", {}).get("content", "")
        return clean(raw) if raw else "错误：模型返回空内容"
    except urllib.error.URLError as e:
        return f"无法连接 Ollama: {e}\n\n请确认 Ollama 正在运行且已下载 {MODEL_NAME}"
    except Exception as e:
        return f"翻译失败: {e}"

def show(orig, trans, src_label, tgt_label):
    if os.path.exists(UI_BINARY):
        subprocess.run([UI_BINARY, orig, trans, src_label, tgt_label, MODEL_NAME])
    else:
        subprocess.run(["osascript", "-e", """
        on run argv
            set r to display dialog (item 2 of argv) buttons {"拷贝译文","关闭"} default button "拷贝译文" with title "翻译"
            if button returned of r is "拷贝译文" then
                set the clipboard to (item 2 of argv)
            end if
        end run""", orig, trans])

text = sys.argv[1].strip() if len(sys.argv) > 1 else ""
if text:
    subprocess.Popen(["osascript", "-e", 'display notification "正在翻译..." with title "🌍 翻译中"'])
    src_cn, target_en, src_label, tgt_label = detect_lang(text)
    result = translate(text, target_en)
    show(text, result, src_label, tgt_label)
else:
    subprocess.run(["osascript", "-e", 'display dialog "请先选中文本再调用翻译" buttons {"OK"} with title "提示" with icon note'])
PYEOF
```

### 第 4 步：保存并使用
1. 按 `Command (⌘) + S` 保存。
2. 命名为 **"🌟 AI 本地翻译"** (或任何您喜欢的名字)。
3. 在任意软件中选中文字，右键 -> **服务** -> **🌟 AI 本地翻译** 即可体验！

> [!TIP]
> **设置快捷键**：前往 **系统设置 > 键盘 > 键盘快捷键 > 服务**，找到您保存的名称并录入快捷键（如 `⌘⇧T`）。

> [!TIP]
> **切换模型**：只需修改嵌入脚本中第 5 行的 `MODEL_NAME` 即可。例如改为 `"llama3.2"` 或 `"gemma3:27b"` 等。
