# ============================================================
#  TIKTOK LIVE CHAT BRIDGE - Python Helper
#  Menghubungkan ke TikTok Live dan menyimpan chat ke JSON
# ============================================================

import sys
import os
import subprocess

# ── AUTO-INSTALL LIBRARY TIKTOK_LIVE JIKA BELUM ADA ──
try:
    from TikTokLive import TikTokLiveClient
    from TikTokLive.events import ConnectEvent, CommentEvent, DisconnectEvent
except ImportError:
    print("[TikTok Bridge] Library 'TikTokLive' belum terinstall.")
    print("[TikTok Bridge] Sedang menginstall TikTokLive via pip... Harap tunggu.")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "TikTokLive"])
        from TikTokLive import TikTokLiveClient
        from TikTokLive.events import ConnectEvent, CommentEvent, DisconnectEvent
        print("[TikTok Bridge] Install berhasil!")
    except Exception as e:
        print(f"[TikTok Bridge] Gagal menginstall library: {e}")
        input("Tekan Enter untuk keluar...")
        sys.exit(1)

import json
import asyncio
import ctypes
from datetime import datetime

# Konfigurasi Path
CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(CONFIG_DIR, "live_chat.json")

# Inisialisasi JSON kosong
try:
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump([], f)
except Exception as e:
    print(f"Gagal inisialisasi file JSON: {e}")

messages = []

def save_to_json():
    try:
        with open(JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(messages, f, ensure_ascii=False, indent=4)
    except Exception as e:
        print(f"Gagal menyimpan ke JSON: {e}")

# Membaca username dari argumen
if len(sys.argv) < 2:
    print("[TikTok Bridge] Guna: python tiktok_bridge.py @username")
    username = input("Masukkan TikTok Username (contoh: @username): ")
else:
    username = sys.argv[1]

if not username.startswith("@"):
    username = "@" + username

# Set judul console Windows agar bisa di-taskkill dari Lua
try:
    ctypes.windll.kernel32.SetConsoleTitleW(f"TikTok Live: {username}")
except Exception:
    pass

client = TikTokLiveClient(unique_id=username)

@client.on(ConnectEvent)
async def on_connect(event: ConnectEvent):
    print(f"\n==========================================")
    print(f" BERHASIL TERHUBUNG KE TIKTOK LIVE")
    print(f" Username: {username}")
    print(f" Room ID:  {client.room_id}")
    print(f" Menulis chat ke: config/ttchat/live_chat.json")
    print(f"==========================================")
    print("Mendengarkan komentar...\n")
    
    # Kirim status SYSTEM ke overlay
    messages.append({
        "author": "SYSTEM",
        "text": f"Terhubung ke TikTok Live {username}!",
        "time": datetime.now().strftime("%H:%M"),
        "is_system": True
    })
    save_to_json()

@client.on(DisconnectEvent)
async def on_disconnect(event: DisconnectEvent):
    print(f"\nTerputus dari live stream.")
    messages.append({
        "author": "SYSTEM",
        "text": "Terputus dari TikTok Live.",
        "time": datetime.now().strftime("%H:%M"),
        "is_system": True
    })
    save_to_json()

@client.on(CommentEvent)
async def on_comment(event: CommentEvent):
    is_moderator = False
    is_subscriber = False
    
    # Cek lencana (badges) untuk mod/sub
    for badge in getattr(event.user, 'badges', []):
        name = getattr(badge, 'name', '').lower()
        b_type = getattr(badge, 'type', '').lower()
        if 'moderator' in name or 'moderator' in b_type:
            is_moderator = True
        if 'subscriber' in name or 'subscriber' in b_type or 'sponsor' in name:
            is_subscriber = True

    msg = {
        "author": event.user.nickname or event.user.unique_id,
        "text": event.comment,
        "time": datetime.now().strftime("%H:%M"),
        "is_moderator": is_moderator,
        "is_subscriber": is_subscriber
    }
    
    messages.append(msg)
    if len(messages) > 30:
        messages.pop(0)
    save_to_json()
    
    # Tampilkan di jendela cmd bridge
    tag = ""
    if is_moderator: tag = "[Mod] "
    elif is_subscriber: tag = "[Sub] "
    print(f"[{msg['time']}] {tag}{msg['author']}: {msg['text']}")

async def start_client():
    try:
        await client.start()
    except Exception as e:
        print(f"\n[TikTok Bridge] Error saat menghubungkan: {e}")
        messages.append({
            "author": "SYSTEM",
            "text": f"Koneksi Gagal: {e}",
            "time": datetime.now().strftime("%H:%M"),
            "is_system": True
        })
        save_to_json()
        input("\nTekan Enter untuk keluar...")

if __name__ == '__main__':
    try:
        asyncio.run(start_client())
    except KeyboardInterrupt:
        print("\nKeluar...")
