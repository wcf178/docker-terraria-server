#!/usr/bin/env python3
"""Small, dependency-free management UI for the Terraria Docker service."""

import hashlib
import hmac
import json
import os
import re
import subprocess
import tarfile
import time
from datetime import datetime
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

WORLDS = Path(os.getenv("WORLDS_DIR", "/worlds"))
CONFIG = Path(os.getenv("CONFIG_DIR", "/config"))
BACKUPS = Path(os.getenv("BACKUPS_DIR", "/backups"))
LOGS = Path(os.getenv("LOGS_DIR", "/logs"))
SERVER_CONTAINER = os.getenv("TERRARIA_CONTAINER", "terraria-server")
PASSWORD = os.getenv("DASHBOARD_PASSWORD", "")
SECRET = os.getenv("DASHBOARD_SECRET", PASSWORD or "local-development-only").encode()
NAME_RE = re.compile(r"^[A-Za-z0-9_-]{1,48}$")

for directory in (WORLDS, CONFIG / "worlds", BACKUPS, LOGS):
    directory.mkdir(parents=True, exist_ok=True)


def config_path(name):
    if not NAME_RE.fullmatch(name):
        raise ValueError("世界名称只能使用字母、数字、下划线和连字符，最长 48 个字符。")
    return CONFIG / "worlds" / f"{name}.conf"


def read_config(path):
    values = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    return values


def active_world():
    active = CONFIG / ".active-world"
    return active.read_text(encoding="utf-8").strip() if active.exists() else ""


def worlds():
    active = active_world()
    result = []
    for path in sorted((CONFIG / "worlds").glob("*.conf")):
        name = path.stem
        settings = read_config(path)
        world_file = WORLDS / f"{name}.wld"
        result.append({
            "name": name,
            "active": name == active,
            "exists": world_file.exists(),
            "bytes": world_file.stat().st_size if world_file.exists() else 0,
            "modified": datetime.fromtimestamp(world_file.stat().st_mtime).isoformat(timespec="seconds") if world_file.exists() else None,
            "port": settings.get("port", "7777"),
            "maxplayers": settings.get("maxplayers", "16"),
            "worldsize": settings.get("worldsize", "2"),
            "difficulty": settings.get("difficulty", "0"),
            "seed": settings.get("seed", ""),
            "password": bool(settings.get("password")),
        })
    return result


def docker(*args):
    try:
        completed = subprocess.run(["docker", *args], text=True, capture_output=True, timeout=45, check=False)
        return completed.returncode == 0, (completed.stdout + completed.stderr).strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)


def server_status():
    ok, output = docker("inspect", "-f", "{{.State.Status}}", SERVER_CONTAINER)
    return {"container": SERVER_CONTAINER, "state": output if ok else "unavailable", "docker": ok}


def create_backup(prefix="manual"):
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = BACKUPS / f"{prefix}-worlds-{stamp}.tar.gz"
    with tarfile.open(target, "w:gz") as archive:
        for item in WORLDS.iterdir():
            archive.add(item, arcname=item.name)
    return target.name


def backups():
    items = []
    for path in sorted(BACKUPS.glob("*.tar.gz"), key=lambda item: item.stat().st_mtime, reverse=True):
        stat = path.stat()
        items.append({"name": path.name, "bytes": stat.st_size, "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds")})
    return items


def signed_cookie():
    expiry = str(int(time.time()) + 86400)
    signature = hmac.new(SECRET, expiry.encode(), hashlib.sha256).hexdigest()
    return f"{expiry}.{signature}"


def valid_cookie(header):
    if not PASSWORD:
        return True
    cookie = SimpleCookie(header or "")
    value = cookie.get("terraria_session")
    if not value or "." not in value.value:
        return False
    expiry, signature = value.value.split(".", 1)
    expected = hmac.new(SECRET, expiry.encode(), hashlib.sha256).hexdigest()
    return expiry.isdigit() and int(expiry) >= time.time() and hmac.compare_digest(signature, expected)


PAGE = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Terraria Control</title><style>
:root{--ink:#17211d;--muted:#66736d;--line:#d9e1db;--paper:#f7faf7;--panel:#fff;--green:#176b48;--mint:#dff2e8;--gold:#b26e18;--danger:#a53832}*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font:14px system-ui,-apple-system,"Segoe UI",sans-serif}button,input,select{font:inherit}button{cursor:pointer;border:0;border-radius:6px;padding:9px 13px;background:var(--green);color:#fff;font-weight:650}button.secondary{background:#edf2ee;color:#24322b}button.danger{background:#fff1f0;color:var(--danger)}button:disabled{opacity:.5;cursor:not-allowed}.shell{max-width:1180px;margin:auto;padding:28px 24px 50px}.top{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line);padding-bottom:22px}.brand{display:flex;gap:12px;align-items:center}.mark{width:37px;height:37px;border-radius:7px;background:var(--green);color:#fff;display:grid;place-items:center;font-weight:800;font-size:18px}.brand h1{font-size:18px;margin:0}.brand p{margin:3px 0 0;color:var(--muted);font-size:12px}.status{display:flex;align-items:center;gap:7px;color:var(--muted)}.dot{height:9px;width:9px;border-radius:50%;background:var(--gold)}.dot.up{background:#1d9a65}.grid{display:grid;grid-template-columns:1.65fr 1fr;gap:22px;margin-top:24px}.section{border:1px solid var(--line);border-radius:7px;background:var(--panel)}.heading{display:flex;justify-content:space-between;align-items:center;padding:17px 18px;border-bottom:1px solid var(--line)}h2{font-size:15px;margin:0}small,.muted{color:var(--muted)}.worlds{padding:0 18px}.world{display:grid;grid-template-columns:1.5fr 1fr .8fr auto;align-items:center;gap:12px;padding:15px 0;border-bottom:1px solid #edf0ed}.world:last-child{border-bottom:0}.world-name{font-weight:700}.badge{display:inline-block;margin-left:7px;padding:2px 6px;background:var(--mint);color:var(--green);border-radius:4px;font-size:11px;font-weight:700}.actions{display:flex;gap:6px;justify-content:flex-end}.actions button{padding:7px 9px;font-size:12px}.form{padding:18px;display:grid;grid-template-columns:1fr 1fr;gap:13px}.field{display:grid;gap:6px}.field.full{grid-column:1/-1}label{font-size:12px;font-weight:650;color:#45534c}input,select{width:100%;border:1px solid #c8d3cb;border-radius:5px;padding:9px;background:#fff;color:var(--ink)}.form footer{grid-column:1/-1;display:flex;justify-content:flex-end;gap:8px;padding-top:3px}.backup{padding:5px 18px 14px}.backup-row{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #edf0ed}.backup-row:last-child{border:0}.backup-row span{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.logs{grid-column:1/-1}.logs pre{margin:0;padding:15px 18px;min-height:140px;max-height:260px;overflow:auto;background:#15211a;color:#d6eadc;font:12px ui-monospace,Consolas,monospace;white-space:pre-wrap}.empty{padding:30px 0;color:var(--muted);text-align:center}.toast{position:fixed;right:20px;bottom:20px;background:#18251e;color:#fff;padding:12px 15px;border-radius:6px;box-shadow:0 7px 20px #0003;display:none}.login{max-width:370px;margin:15vh auto;padding:28px;border:1px solid var(--line);border-radius:7px;background:#fff}.login h1{margin:0 0 7px}.login form{display:grid;gap:14px;margin-top:22px}@media(max-width:760px){.shell{padding:18px 14px}.grid{grid-template-columns:1fr}.world{grid-template-columns:1fr auto}.world .details{display:none}.form{grid-template-columns:1fr}.top{align-items:flex-start}.status{font-size:12px}.actions{grid-column:2}.world-name{grid-column:1}.logs{grid-column:auto}}
</style></head><body><main class="shell"><header class="top"><div class="brand"><div class="mark">T</div><div><h1>Terraria Control</h1><p>世界、备份与服务器运行状态</p></div></div><div class="status"><i class="dot" id="dot"></i><span id="status">正在连接...</span></div></header><div class="grid"><section class="section"><div class="heading"><div><h2>世界</h2><small>一次运行一个世界，切换时会安全重启服务。</small></div><button class="secondary" onclick="load()">刷新</button></div><div class="worlds" id="worlds"></div></section><section class="section"><div class="heading"><div><h2>创建世界</h2><small>所有可切换世界共用游戏端口 7777。</small></div></div><form class="form" id="create"><div class="field full"><label>世界名称</label><input name="name" required pattern="[A-Za-z0-9_-]+" placeholder="例如：survival"></div><div class="field"><label>世界尺寸</label><select name="worldsize"><option value="1">小</option><option value="2" selected>中</option><option value="3">大</option></select></div><div class="field"><label>难度</label><select name="difficulty"><option value="0">经典</option><option value="1">专家</option><option value="2">大师</option><option value="3">旅行</option></select></div><div class="field full"><label>最大玩家数</label><input name="maxplayers" type="number" min="1" max="255" value="16"></div><div class="field full"><label>种子（可选）</label><input name="seed" placeholder="留空则随机生成"></div><div class="field full"><label>服务器密码（可选）</label><input name="password" type="password" autocomplete="new-password"></div><footer><button type="reset" class="secondary">清空</button><button>创建世界</button></footer></form></section><section class="section"><div class="heading"><div><h2>备份</h2><small>手动备份会保存当前所有世界文件。</small></div><button onclick="manualBackup()">立即备份</button></div><div class="backup" id="backups"></div></section><section class="section"><div class="heading"><div><h2>操作</h2><small>切换世界和重启使用 Docker socket。</small></div></div><div class="backup"><div class="backup-row"><span>重启当前 Terraria 服务</span><button class="secondary" onclick="restart()">重启</button></div><div class="backup-row"><span>页面每 20 秒自动刷新状态</span><button class="secondary" onclick="loadLogs()">查看日志</button></div></div></section><section class="section logs"><div class="heading"><div><h2>启动日志</h2><small>最近 120 行</small></div></div><pre id="logs">选择“查看日志”加载。</pre></section></div></main><div class="toast" id="toast"></div><script>
const $=s=>document.querySelector(s), size=n=>n<1024?n+' B':n<1048576?(n/1024).toFixed(1)+' KB':(n/1048576).toFixed(1)+' MB'; const diff=['经典','专家','大师','旅行'],worldSize=['','小','中','大'];
async function api(url,opts={}){const r=await fetch(url,opts);const d=await r.json().catch(()=>({message:'请求失败'}));if(!r.ok)throw Error(d.message||'请求失败');return d} function notice(s){const e=$('#toast');e.textContent=s;e.style.display='block';setTimeout(()=>e.style.display='none',3200)}
function renderWorlds(items){const el=$('#worlds');el.innerHTML=items.length?items.map(w=>`<div class="world"><div><span class="world-name">${w.name}</span>${w.active?'<span class="badge">当前运行</span>':''}<div class="muted">${w.exists?'已生成 · '+size(w.bytes):'等待首次生成'}</div></div><div class="details"><b>${diff[+w.difficulty]||'经典'}</b><div class="muted">${worldSize[+w.worldsize]||'中'}型世界 · ${w.maxplayers} 人</div></div><div class="details"><b>${w.port}</b><div class="muted">游戏端口${w.password?' · 已设密码':''}</div></div><div class="actions">${w.active?'':`<button onclick="activate('${w.name}')">运行</button>`}<button class="secondary" onclick="backupWorld('${w.name}')">备份</button>${w.active?'':`<button class="danger" onclick="removeWorld('${w.name}')">删除</button>`}</div></div>`).join(''):'<div class="empty">还没有世界。创建第一个世界后，点击“运行”即可启动它。</div>'}
function renderBackups(items){$('#backups').innerHTML=items.length?items.slice(0,6).map(b=>`<div class="backup-row"><span title="${b.name}">${b.name}<small> · ${size(b.bytes)} · ${new Date(b.modified).toLocaleString()}</small></span><button class="danger" onclick="deleteBackup('${b.name}')">删除</button></div>`).join(''):'<div class="empty">尚无备份。</div>'}
async function load(){try{const [s,w,b]=await Promise.all([api('/api/status'),api('/api/worlds'),api('/api/backups')]);$('#status').textContent=s.state==='running'?'服务运行中':s.state==='restarting'?'服务重启中':s.docker?'服务未运行':'无法连接 Docker';$('#dot').className='dot '+(s.state==='running'?'up':'');renderWorlds(w);renderBackups(b)}catch(e){notice(e.message)}}
async function post(url,data){return api(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data||{})})} async function activate(n){if(!confirm(`切换到“${n}”会重启服务器，确定继续吗？`))return;try{notice((await post('/api/worlds/'+n+'/activate')).message);load()}catch(e){notice(e.message)}} async function removeWorld(n){if(!confirm(`删除“${n}”的配置与世界文件不可恢复，确定吗？`))return;try{notice((await post('/api/worlds/'+n+'/delete')).message);load()}catch(e){notice(e.message)}} async function restart(){try{notice((await post('/api/restart')).message);load()}catch(e){notice(e.message)}} async function manualBackup(){try{notice((await post('/api/backups')).message);load()}catch(e){notice(e.message)}} async function backupWorld(n){try{notice((await post('/api/backups',{world:n})).message);load()}catch(e){notice(e.message)}} async function deleteBackup(n){if(!confirm('删除此备份？'))return;try{notice((await post('/api/backups/'+n+'/delete')).message);load()}catch(e){notice(e.message)}} async function loadLogs(){try{$('#logs').textContent=(await api('/api/logs')).text}catch(e){notice(e.message)}}
$('#create').addEventListener('submit',async e=>{e.preventDefault();const d=Object.fromEntries(new FormData(e.target));try{const r=await post('/api/worlds',d);notice(r.message);e.target.reset();load()}catch(err){notice(err.message)}});load();setInterval(load,20000);
</script></body></html>'''


LOGIN = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Terraria Control</title><style>body{background:#f7faf7;color:#17211d;font:14px system-ui,sans-serif}.login{max-width:370px;margin:15vh auto;padding:28px;border:1px solid #d9e1db;border-radius:7px;background:#fff}h1{margin:0 0 7px}p{color:#66736d}form{display:grid;gap:14px;margin-top:22px}input,button{font:inherit;padding:10px;border-radius:5px}input{border:1px solid #c8d3cb}button{border:0;background:#176b48;color:#fff;font-weight:700}</style><main class="login"><h1>Terraria Control</h1><p>输入后台密码以继续。</p><form method="post" action="/login"><input name="password" type="password" autofocus required><button>进入后台</button></form></main></html>'''


class App(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def send_json(self, payload, status=200):
        content = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def read_body(self):
        length = int(self.headers.get("Content-Length", "0"))
        return self.rfile.read(length)

    def authenticated(self):
        return valid_cookie(self.headers.get("Cookie"))

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/login" and PASSWORD:
            return self.html(LOGIN)
        if not self.authenticated():
            self.send_response(HTTPStatus.SEE_OTHER)
            self.send_header("Location", "/login")
            self.end_headers()
            return
        if path == "/": return self.html(PAGE)
        if path == "/api/status": return self.send_json(server_status())
        if path == "/api/worlds": return self.send_json(worlds())
        if path == "/api/backups": return self.send_json(backups())
        if path == "/api/logs":
            file = LOGS / "entrypoint.log"
            text = "\n".join(file.read_text(encoding="utf-8", errors="replace").splitlines()[-120:]) if file.exists() else "暂无启动日志。"
            return self.send_json({"text": text})
        return self.send_json({"message": "未找到接口。"}, 404)

    def html(self, page):
        content = page.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/login":
            values = parse_qs(self.read_body().decode())
            supplied = values.get("password", [""])[0]
            if PASSWORD and hmac.compare_digest(supplied, PASSWORD):
                self.send_response(303); self.send_header("Location", "/")
                self.send_header("Set-Cookie", f"terraria_session={signed_cookie()}; HttpOnly; SameSite=Strict; Path=/; Max-Age=86400")
                self.end_headers(); return
            return self.html(LOGIN)
        if not self.authenticated(): return self.send_json({"message": "登录已过期。"}, 401)
        try:
            data = json.loads(self.read_body() or b"{}")
            if path == "/api/worlds": return self.create_world(data)
            if path == "/api/restart": return self.restart()
            if path == "/api/backups":
                name = data.get("world", "")
                if name: config_path(name)
                backup = create_backup(name or "manual")
                return self.send_json({"message": f"已创建备份：{backup}"})
            match = re.fullmatch(r"/api/worlds/([^/]+)/activate", path)
            if match: return self.activate(match.group(1))
            match = re.fullmatch(r"/api/worlds/([^/]+)/delete", path)
            if match: return self.delete_world(match.group(1))
            match = re.fullmatch(r"/api/backups/([^/]+)/delete", path)
            if match: return self.delete_backup(match.group(1))
            return self.send_json({"message": "未找到接口。"}, 404)
        except (ValueError, KeyError) as exc:
            return self.send_json({"message": str(exc)}, 400)
        except Exception as exc:
            return self.send_json({"message": f"操作失败：{exc}"}, 500)

    def create_world(self, data):
        name = str(data.get("name", "")).strip()
        path = config_path(name)
        if path.exists(): raise ValueError("同名世界已存在。")
        port, players = "7777", str(data.get("maxplayers", "16"))
        size, difficulty = str(data.get("worldsize", "2")), str(data.get("difficulty", "0"))
        if not port.isdigit() or not 1 <= int(port) <= 65535: raise ValueError("端口必须在 1 到 65535 之间。")
        if not players.isdigit() or not 1 <= int(players) <= 255: raise ValueError("玩家数必须在 1 到 255 之间。")
        if size not in {"1", "2", "3"} or difficulty not in {"0", "1", "2", "3"}: raise ValueError("世界尺寸或难度无效。")
        lines = [f"# World configuration for: {name}", f"world=/worlds/{name}.wld", "autocreate=1", f"worldsize={size}", f"difficulty={difficulty}", f"port={port}", f"maxplayers={players}", "language=en-US", "autosave=1"]
        if data.get("password"): lines.append(f"password={str(data['password']).replace(chr(10), '')}")
        if data.get("seed"): lines.append(f"seed={str(data['seed']).replace(chr(10), '')}")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return self.send_json({"message": f"世界“{name}”已创建。点击“运行”后生成世界。"}, 201)

    def activate(self, name):
        if not config_path(name).exists(): raise ValueError("世界不存在。")
        (CONFIG / ".active-world").write_text(name + "\n", encoding="utf-8")
        ok, output = docker("restart", SERVER_CONTAINER)
        message = f"已切换到“{name}”并请求重启服务器。" if ok else f"已设置活动世界“{name}”，但重启失败：{output}"
        return self.send_json({"message": message}, 200 if ok else 503)

    def restart(self):
        ok, output = docker("restart", SERVER_CONTAINER)
        return self.send_json({"message": "已请求重启服务器。" if ok else f"重启失败：{output}"}, 200 if ok else 503)

    def delete_world(self, name):
        path = config_path(name)
        if not path.exists(): raise ValueError("世界不存在。")
        if active_world() == name: raise ValueError("不能删除当前活动世界，请先切换到另一个世界。")
        path.unlink()
        for suffix in (".wld", ".wld.bak"):
            (WORLDS / f"{name}{suffix}").unlink(missing_ok=True)
        return self.send_json({"message": f"世界“{name}”及其文件已删除。"})

    def delete_backup(self, name):
        if Path(name).name != name or not name.endswith(".tar.gz"): raise ValueError("备份文件名无效。")
        target = BACKUPS / name
        if not target.exists(): raise ValueError("备份不存在。")
        target.unlink()
        return self.send_json({"message": "备份已删除。"})


if __name__ == "__main__":
    host, port = os.getenv("DASHBOARD_HOST", "0.0.0.0"), int(os.getenv("DASHBOARD_PORT", "8080"))
    print(f"Terraria dashboard listening on {host}:{port}")
    ThreadingHTTPServer((host, port), App).serve_forever()
