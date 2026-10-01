#!/usr/bin/env python3
"""Herramienta de la plataforma: lee stack.json y clients/*/client.json.

Uso:
  stack.py validate                     valida stack.json y todos los client.json
  stack.py matrix                       lista de clientes (JSON) para la matriz del CI
  stack.py apps CLIENTE                 apps en orden de instalacion
  stack.py fetch DESTINO CLIENTE        descarga core + opcionales del cliente en DESTINO, fijados por commit
  stack.py due [--now ISO8601]          clientes cuya ventana de mantenimiento esta abierta ahora
  stack.py get CLIENTE CAMPO            imprime un campo del client.json (ej: site, timezone, release)
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def load_stack():
	return json.loads((ROOT / "stack.json").read_text())


def client_dirs():
	return sorted(p.parent for p in (ROOT / "clients").glob("*/client.json"))


def load_client(name):
	path = ROOT / "clients" / name / "client.json"
	if not path.exists():
		sys.exit(f"Cliente inexistente: {name}")
	return json.loads(path.read_text())


def app_order(client):
	stack = load_stack()
	apps = list(stack["core"])
	apps += client.get("optional_apps", [])
	apps.append("agentic_base")
	if client.get("app"):
		apps.append(client["app"]["name"])
	return apps


def app_source(name, client):
	"""Devuelve ('git', repo, commit) o ('path', ruta_absoluta)."""
	stack = load_stack()
	pinned = {**stack["core"], **stack.get("optional", {})}
	if name in pinned:
		spec = pinned[name]
		return ("git", spec["repo"], spec["commit"])
	if name == "agentic_base":
		return ("path", str(ROOT / stack["base_app"]))
	app = client.get("app") or {}
	if app.get("name") == name:
		if app.get("path"):
			return ("path", str(ROOT / app["path"]))
		return ("git", app["repo"], app["commit"])
	sys.exit(f"No se sabe de donde sale la app {name}")


def cmd_validate(_args):
	errors = []
	stack = load_stack()
	pinned = {**stack["core"], **stack.get("optional", {})}
	for name, spec in pinned.items():
		if len(spec.get("commit", "")) != 40:
			errors.append(f"stack.json: {name} debe fijarse por commit completo (40 caracteres)")
	for d in client_dirs():
		c = json.loads((d / "client.json").read_text())
		where = f"clients/{d.name}/client.json"
		if c.get("name") != d.name:
			errors.append(f"{where}: name debe ser '{d.name}'")
		for key in ("site", "timezone", "maintenance_window", "deploy"):
			if key not in c:
				errors.append(f"{where}: falta '{key}'")
		try:
			ZoneInfo(c.get("timezone", ""))
		except Exception:
			errors.append(f"{where}: zona horaria invalida '{c.get('timezone')}'")
		w = c.get("maintenance_window", {})
		if not set(w.get("days", [])) <= set(DAYS) or not w.get("days"):
			errors.append(f"{where}: maintenance_window.days debe usar {DAYS}")
		try:
			datetime.strptime(w.get("start", ""), "%H:%M")
		except ValueError:
			errors.append(f"{where}: maintenance_window.start debe ser HH:MM")
		for opt in c.get("optional_apps", []):
			if opt not in stack.get("optional", {}):
				errors.append(f"{where}: app opcional desconocida '{opt}'")
		app = c.get("app")
		if app:
			if app.get("path") and not (ROOT / app["path"] / app["name"] / "hooks.py").exists():
				errors.append(f"{where}: no existe {app['path']}/{app['name']}/hooks.py")
			if not app.get("path") and not (app.get("repo") and len(app.get("commit", "")) == 40):
				errors.append(f"{where}: app externa necesita repo y commit completo")
		if c.get("deploy", {}).get("enabled") and not c.get("release"):
			errors.append(f"{where}: deploy habilitado sin 'release' (tag de imagen aprobado)")
	if errors:
		print("\n".join(errors), file=sys.stderr)
		sys.exit(1)
	print(f"OK: {len(client_dirs())} clientes validos")


def cmd_matrix(_args):
	print(json.dumps([d.name for d in client_dirs()]))


def cmd_apps(args):
	print(" ".join(app_order(load_client(args.client))))


def git(*args, cwd=None):
	subprocess.run(["git", *args], cwd=cwd, check=True)


def cmd_fetch(args):
	client = load_client(args.client)
	dest = Path(args.dest).resolve()
	dest.mkdir(parents=True, exist_ok=True)
	for name in app_order(client):
		source = app_source(name, client)
		target = dest / name
		if source[0] == "path":
			continue
		_, repo, commit = source
		if (target / ".git").exists():
			head = subprocess.run(
				["git", "rev-parse", "HEAD"], cwd=target, capture_output=True, text=True
			).stdout.strip()
			if head == commit:
				print(f"{name}: ya en {commit[:12]}")
				continue
		target.mkdir(exist_ok=True)
		git("init", "-q", cwd=target)
		git("fetch", "-q", "--depth", "1", repo, commit, cwd=target)
		git("checkout", "-q", "--force", "FETCH_HEAD", cwd=target)
		git("submodule", "update", "--init", "--recursive", "--depth", "1", cwd=target)
		print(f"{name}: {commit[:12]}")


def window_open(client, now):
	w = client["maintenance_window"]
	tz = ZoneInfo(client["timezone"])
	local = now.astimezone(tz)
	start_h, start_m = map(int, w["start"].split(":"))
	duration = timedelta(minutes=w.get("duration_minutes", 120))
	# Revisa la ventana que empezo hoy y la de ayer (por si cruza la medianoche)
	for back in (0, 1):
		day = local - timedelta(days=back)
		if DAYS[day.weekday()] not in w["days"]:
			continue
		start = day.replace(hour=start_h, minute=start_m, second=0, microsecond=0)
		if start <= local < start + duration:
			return True
	return False


def cmd_due(args):
	now = datetime.fromisoformat(args.now) if args.now else datetime.now(timezone.utc)
	if now.tzinfo is None:
		now = now.replace(tzinfo=timezone.utc)
	due = []
	for d in client_dirs():
		c = json.loads((d / "client.json").read_text())
		if c.get("deploy", {}).get("enabled") and c.get("release") and window_open(c, now):
			due.append(c["name"])
	print(json.dumps(due))


def cmd_get(args):
	value = load_client(args.client)
	for part in args.field.split("."):
		value = value.get(part) if isinstance(value, dict) else None
	print(value if not isinstance(value, (dict, list)) else json.dumps(value))


def main():
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = parser.add_subparsers(dest="cmd", required=True)
	sub.add_parser("validate").set_defaults(func=cmd_validate)
	sub.add_parser("matrix").set_defaults(func=cmd_matrix)
	p = sub.add_parser("apps")
	p.add_argument("client")
	p.set_defaults(func=cmd_apps)
	p = sub.add_parser("fetch")
	p.add_argument("dest")
	p.add_argument("client")
	p.set_defaults(func=cmd_fetch)
	p = sub.add_parser("due")
	p.add_argument("--now")
	p.set_defaults(func=cmd_due)
	p = sub.add_parser("get")
	p.add_argument("client")
	p.add_argument("field")
	p.set_defaults(func=cmd_get)
	args = parser.parse_args()
	args.func(args)


if __name__ == "__main__":
	main()
