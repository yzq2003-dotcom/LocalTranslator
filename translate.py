#!/usr/bin/env python3
# ============================================================
# 🌍 本地模型右键翻译工具 — translate.py
# 调用本地 Ollama，通过 Swift 原生 UI 展示翻译结果
# ============================================================

import sys
import json
import re
import urllib.request
import urllib.error
import subprocess
import os

# ========================================
# ⚙️ 配置区 / CONFIGURATION
# ========================================
MODEL_NAME = "qwen3.5:9b"     # ← 想换模型？改这一行即可
OLLAMA_API_URL = "http://localhost:11434/api/chat"
TIMEOUT_SECONDS = 60           # 本地模型推理超时时间（秒）

# UI 二进制路径（与本脚本同目录）
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
UI_BINARY = os.path.join(SCRIPT_DIR, "TranslatorUI")

# ========================================
# 🔍 语言检测
# ========================================
def detect_language(text):
    """简易语言检测：根据 CJK 字符占比判断"""
    cjk_count = sum(1 for ch in text if '\u4e00' <= ch <= '\u9fff' or '\u3400' <= ch <= '\u4dbf')
    ratio = cjk_count / max(len(text), 1)
    if ratio > 0.15:
        return "中文", "Chinese"
    else:
        return "英文", "English"

def get_target_info(source_lang_cn):
    """根据源语言确定翻译方向"""
    if source_lang_cn == "中文":
        return "英文", "English", "中文", "English"
    else:
        return "中文", "Chinese", "English", "中文"

# ========================================
# 🧹 清洗模型输出
# ========================================
def clean_model_output(text):
    """
    清理模型输出：
    1. 移除 qwen3 系列的 <think>...</think> 思考过程
    2. 移除可能残留的 markdown 格式
    3. 去除首尾空白
    """
    # 移除 <think>...</think> 块（包括多行内容）
    text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL)
    # 如果模型只返回了 think 块而没有实际内容，保留原文提示
    text = text.strip()
    if not text:
        return "[模型未返回有效翻译内容]"
    return text

# ========================================
# 📡 调用 Ollama API
# ========================================
def translate(text, target_lang_en):
    """向本地 Ollama 发送翻译请求"""
    prompt = (
        f"Translate the following text into {target_lang_en}. "
        f"Output ONLY the translation, nothing else. No explanations, no original text, no quotes.\n\n"
        f"{text}"
    )

    data = {
        "model": MODEL_NAME,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False
    }

    req = urllib.request.Request(OLLAMA_API_URL, data=json.dumps(data).encode('utf-8'))
    req.add_header('Content-Type', 'application/json')

    try:
        response = urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS)
        result = json.loads(response.read().decode('utf-8'))
        raw_content = result.get("message", {}).get("content", "")
        return clean_model_output(raw_content) if raw_content else "错误：模型返回了空内容"
    except urllib.error.URLError as e:
        return (
            f"⚠️ 无法连接到本地 Ollama\n\n"
            f"错误: {e}\n\n"
            f"请检查:\n"
            f"1. Ollama 是否正在运行\n"
            f"2. 模型 {MODEL_NAME} 是否已下载\n"
            f"   (运行: ollama pull {MODEL_NAME})"
        )
    except json.JSONDecodeError:
        return "错误：无法解析模型响应"
    except TimeoutError:
        return f"翻译超时（{TIMEOUT_SECONDS}秒），模型可能正在加载中，请重试"
    except Exception as e:
        return f"翻译失败: {type(e).__name__}: {e}"

# ========================================
# 🖥️ 显示翻译结果
# ========================================
def show_loading_notification():
    """发送"正在翻译"系统通知"""
    subprocess.Popen([
        'osascript', '-e',
        'display notification "正在调用本地模型，请稍候..." with title "🌍 翻译中"'
    ])

def show_result(original, translated, source_label, target_label):
    """调用 Swift 原生 UI 展示翻译结果"""
    if os.path.exists(UI_BINARY):
        subprocess.run([UI_BINARY, original, translated, source_label, target_label, MODEL_NAME])
    else:
        # 兜底：如果 Swift 二进制不存在，使用 AppleScript
        applescript = """
        on run argv
            set dialogResult to display dialog (item 1 of argv) buttons {"拷贝译文", "关闭"} default button "拷贝译文" with title "本地模型翻译"
            if button returned of dialogResult is "拷贝译文" then
                set the clipboard to (item 1 of argv)
                display notification "译文已拷贝到剪贴板" with title "翻译成功" sound name "Glass"
            end if
        end run
        """
        subprocess.run(['osascript', '-e', applescript, translated])

def show_error_dialog(message):
    """显示错误弹窗"""
    subprocess.run([
        'osascript', '-e',
        f'display dialog "{message}" buttons {{"OK"}} default button "OK" with title "翻译工具" with icon stop'
    ])

# ========================================
# 🚀 主流程
# ========================================
if __name__ == "__main__":
    # 获取待翻译文本（stdin 优先，命令行参数备用）
    text_to_translate = ""

    if not sys.stdin.isatty():
        text_to_translate = sys.stdin.read().strip()

    if not text_to_translate and len(sys.argv) > 1:
        text_to_translate = " ".join(sys.argv[1:])

    if not text_to_translate:
        show_error_dialog("未获取到需要翻译的文本。\\n请先划选文本再右键调用翻译。")
        sys.exit(1)

    # 检测语言 & 确定翻译方向
    source_lang_cn, source_lang_en = detect_language(text_to_translate)
    target_lang_cn, target_lang_en, source_label, target_label = get_target_info(source_lang_cn)

    # 显示加载通知
    show_loading_notification()

    # 执行翻译
    translated_text = translate(text_to_translate, target_lang_en)

    # 展示结果
    show_result(text_to_translate, translated_text, source_label, target_label)
