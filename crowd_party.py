import math
import random
import tkinter as tk

WIDTH = 1100
HEIGHT = 720

BG = "#1c2430"
GRID = "#2d3b4d"
ROOMS = {
    "office": [
        {"name": "Sala de Reunião", "x": 120, "y": 120, "w": 220, "h": 170, "fill": "#7d9fe0"},
        {"name": "Baias", "x": 430, "y": 410, "w": 280, "h": 180, "fill": "#8ec7a5"},
        {"name": "Cafeteria", "x": 820, "y": 150, "w": 210, "h": 180, "fill": "#f0b66d"},
    ],
    "school": [
        {"name": "Sala de Aula", "x": 150, "y": 130, "w": 220, "h": 180, "fill": "#7fa9eb"},
        {"name": "Laboratório", "x": 480, "y": 420, "w": 260, "h": 170, "fill": "#81d6a8"},
        {"name": "Biblioteca", "x": 860, "y": 200, "w": 200, "h": 180, "fill": "#dca66a"},
    ],
    "street": [
        {"name": "Padaria", "x": 150, "y": 150, "w": 200, "h": 180, "fill": "#b4a0ff"},
        {"name": "Mercado", "x": 500, "y": 420, "w": 220, "h": 170, "fill": "#8fd9b5"},
        {"name": "Praça", "x": 860, "y": 180, "w": 210, "h": 170, "fill": "#f1bb73"},
    ],
}

TEAM_COLOR = "#6cd69d"
HORDE_COLOR = "#d96f6f"
PLAYER_COLOR = "#f0efe8"
TEXT = "#f9fafb"
DIM_TEXT = "#dfeaf8"
ACCENT = "#f4d35e"
BUTTON = "#f4b942"
BUTTON_DARK = "#dca92a"


class Person:
    def __init__(self, x, y, role="civilian", state="civilian"):
        self.x = x
        self.y = y
        self.role = role
        self.state = state
        self.r = 12
        self.offset = random.uniform(0, 100)

    def draw(self, canvas):
        color = {
            "civilian": "#d9d1be",
            "team": TEAM_COLOR,
            "horde": HORDE_COLOR,
        }[self.state]
        y = self.y + math.sin(self.offset) * 2
        canvas.create_oval(self.x - self.r, y - self.r, self.x + self.r, y + self.r, fill=color, outline="")


class Confetti:
    def __init__(self, x, y, vx, vy, color=None):
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.life = 1.2
        self.color = color or random.choice(["#d7b56d", "#a7b9b0", "#b07264", "#9ca9b7"])

    def update(self, dt):
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += 250 * dt
        self.life -= dt

    def draw(self, canvas):
        canvas.create_oval(self.x - 4, self.y - 4, self.x + 4, self.y + 4, fill=self.color, outline="")


class CrowdParty:
    def __init__(self, root):
        self.root = root
        self.root.title("Crowd Party")
        self.root.geometry(f"{WIDTH}x{HEIGHT}")
        self.root.configure(bg=BG)

        self.menu_frame = tk.Frame(root, bg=BG)
        self.menu_frame.pack(fill="both", expand=True)

        self.game = None
        self.env_name = "office"
        self.phase = 1
        self.show_menu()

    def show_menu(self):
        for child in self.menu_frame.winfo_children():
            child.destroy()

        title = tk.Label(self.menu_frame, text="Crowd Party", bg=BG, fg=TEXT, font=("Segoe UI", 32, "bold"))
        title.pack(pady=(28, 6))

        subtitle = tk.Label(self.menu_frame, text="Recrute a turma antes que a horda avance.", bg=BG, fg=DIM_TEXT, font=("Segoe UI", 16))
        subtitle.pack(pady=(0, 18))

        panel = tk.Frame(self.menu_frame, bg="#2b3644", width=740, height=270)
        panel.pack_propagate(False)
        panel.pack(pady=8)

        env_label = tk.Label(panel, text="Selecione o ambiente", bg="#2b3644", fg=TEXT, font=("Segoe UI", 20, "bold"))
        env_label.pack(pady=(18, 12))

        env_row = tk.Frame(panel, bg="#2b3644")
        env_row.pack()

        for label, env in [("Escritório", "office"), ("Escola", "school"), ("Rua", "street")]:
            btn = tk.Button(
                env_row,
                text=label,
                width=12,
                height=2,
                bg="#4d5d73" if env != self.env_name else "#7ee0a5",
                fg=TEXT,
                activebackground="#7ee0a5",
                activeforeground=TEXT,
                relief="flat",
                font=("Segoe UI", 12, "bold"),
                command=lambda ev=env: self.set_env(ev),
            )
            btn.pack(side="left", padx=16)

        start_btn = tk.Button(
            self.menu_frame,
            text="Iniciar",
            width=16,
            height=2,
            bg=BUTTON,
            fg="#1b1d22",
            activebackground=BUTTON_DARK,
            activeforeground="#1b1d22",
            font=("Segoe UI", 16, "bold"),
            relief="flat",
            command=self.start_game,
        )
        start_btn.pack(pady=(18, 8))

    def set_env(self, env_name):
        self.env_name = env_name
        self.show_menu()

    def start_game(self):
        self.menu_frame.pack_forget()
        self.game = GameSession(self.root, self.env_name)


class GameSession:
    def __init__(self, root, env_name="office"):
        self.root = root
        self.env_name = env_name
        self.canvas = tk.Canvas(root, width=WIDTH, height=HEIGHT, bg=BG, highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)
        self.canvas.focus_set()

        self.base_goal = 12
        self.phase = 1
        self.horde_wave = 0

        self.player = {"x": WIDTH / 2, "y": HEIGHT / 2, "r": 18, "speed": 210}
        self.facing = {"x": 1, "y": 0}
        self.exit = {"x": WIDTH - 78, "y": HEIGHT - 78, "r": 34}
        self.rooms = ROOMS[env_name]
        self.civilians = []
        self.team = []
        self.horde = []
        self.confetti = []
        self.message = "Encontre pessoas para recrutar."
        self.countdown = 60
        self.shot_speed = 280
        self.shot_interval = 0.35
        self.player_shot_timer = 0
        self.goal = self.base_goal
        self.state = "playing"
        self.keys = {"left": False, "right": False, "up": False, "down": False}
        self.horde_timer = 0
        self.team_shot_timer = 0
        self.upgrades = {"speed": 0, "confetti": 0}
        self.upgrade_points = 0
        self._spawn_people()
        self._bind_keys()
        self._tick()

    def _spawn_people(self):
        for room in self.rooms:
            cx = room["x"] + room["w"] / 2
            cy = room["y"] + room["h"] / 2
            for i in range(3):
                angle = (2 * math.pi / 3) * i
                px = cx + math.cos(angle) * 50
                py = cy + math.sin(angle) * 50
                self.civilians.append(Person(px, py, role=self.env_name, state="civilian"))

        for _ in range(8):
            self._spawn_horde_wave(1)

    def _spawn_horde_wave(self, amount=1):
        for _ in range(amount):
            side = random.choice(["left", "right", "top", "bottom"])
            if side == "left":
                x, y = random.randint(-20, 60), random.randint(60, HEIGHT - 60)
            elif side == "right":
                x, y = random.randint(WIDTH - 60, WIDTH + 20), random.randint(60, HEIGHT - 60)
            elif side == "top":
                x, y = random.randint(60, WIDTH - 60), random.randint(-20, 60)
            else:
                x, y = random.randint(60, WIDTH - 60), random.randint(HEIGHT - 60, HEIGHT + 20)
            self.horde.append(Person(x, y, role="horde", state="horde"))

    def _bind_keys(self):
        for key, direction in [("w", "up"), ("Up", "up"), ("s", "down"), ("Down", "down"), ("a", "left"), ("Left", "left"), ("d", "right"), ("Right", "right")]:
            self.root.bind(f"<KeyPress-{key}>", lambda e, name=direction: self._set_key(name, True))
            self.root.bind(f"<KeyRelease-{key}>", lambda e, name=direction: self._set_key(name, False))
        self.root.bind("<KeyPress-space>", self.throw_confetti)
        self.root.bind("<KeyPress-1>", self.buy_speed_upgrade)
        self.root.bind("<KeyPress-2>", self.buy_confetti_upgrade)
        self.root.bind("<KeyPress-r>", lambda e: self.restart_to_menu())

    def _set_key(self, name, value):
        self.keys[name] = value

    def buy_speed_upgrade(self, event=None):
        if self.upgrade_points <= 0:
            self.message = "Sem pontos de upgrade."
            return
        self.upgrade_points -= 1
        self.upgrades["speed"] += 1
        self.player["speed"] += 25
        self.message = "Velocidade aumentada."
        self.root.bell()

    def buy_confetti_upgrade(self, event=None):
        if self.upgrade_points <= 0:
            self.message = "Sem pontos de upgrade."
            return
        self.upgrade_points -= 1
        self.upgrades["confetti"] += 1
        self.message = "Confete mais forte."
        self.root.bell()

    def restart_to_menu(self, event=None):
        for key in ("w", "Up", "s", "Down", "a", "Left", "d", "Right"):
            self.root.unbind(f"<KeyPress-{key}>")
            self.root.unbind(f"<KeyRelease-{key}>")
        self.root.unbind("<KeyPress-space>")
        self.root.unbind("<KeyPress-1>")
        self.root.unbind("<KeyPress-2>")
        self.root.unbind("<KeyPress-r>")
        self.canvas.destroy()
        CrowdParty(self.root)

    def throw_confetti(self, event=None):
        if self.state != "playing":
            return
        if self.player_shot_timer > 0:
            return
        base_angle = math.atan2(self.facing["y"], self.facing["x"])
        angle = base_angle + random.uniform(-0.28, 0.28)
        self.confetti.append(Confetti(self.player["x"], self.player["y"], math.cos(angle) * self.shot_speed, math.sin(angle) * self.shot_speed))
        self.player_shot_timer = self.shot_interval
        self.message = "Disparo de confete! Acerte pessoas para recrutá-las."
        self.root.bell()

    def recruit_nearby(self, event=None):
        return

    def _recruit_person(self, person):
        person.state = "team"
        self.team.append(person)
        self.civilians.remove(person)
        self.upgrade_points += 1
        self.message = "+1 recrutado pelo disparo."

    def _resolve_shot_collisions(self):
        for burst in list(self.confetti):
            for person in list(self.civilians):
                if math.hypot(person.x - burst.x, person.y - burst.y) < person.r + 7:
                    self._recruit_person(person)
                    self.confetti.remove(burst)
                    break
            else:
                for enemy in list(self.horde):
                    if math.hypot(enemy.x - burst.x, enemy.y - burst.y) < enemy.r + 7:
                        self.horde.remove(enemy)
                        self.message = "Inimigo dispersado!"
                        self.confetti.remove(burst)
                        break

    def _update_team(self, dt):
        for index, person in enumerate(self.team):
            angle = index * 0.9
            target_x = self.player["x"] + math.cos(angle) * 48
            target_y = self.player["y"] + math.sin(angle) * 48
            dx = target_x - person.x
            dy = target_y - person.y
            distance = math.hypot(dx, dy)
            if distance > 2:
                step = min(distance, 125 * dt)
                person.x += dx / distance * step
                person.y += dy / distance * step

        self.team_shot_timer += dt
        if self.team_shot_timer < self.shot_interval or not self.team:
            return
        self.team_shot_timer = 0
        for person in self.team:
            targets = [enemy for enemy in self.horde if math.hypot(enemy.x - person.x, enemy.y - person.y) < 260]
            if targets:
                target = min(targets, key=lambda enemy: math.hypot(enemy.x - person.x, enemy.y - person.y))
                dx = target.x - person.x
                dy = target.y - person.y
                distance = math.hypot(dx, dy)
                self.confetti.append(Confetti(person.x, person.y, dx / distance * self.shot_speed, dy / distance * self.shot_speed, color=TEAM_COLOR))
                self.message = "A equipe está atirando!"

    def _advance_horde(self, dt):
        for h in self.horde:
            dx = self.player["x"] - h.x
            dy = self.player["y"] - h.y
            dist = math.hypot(dx, dy)
            if dist > 0:
                speed = 90 + len(self.horde) * 2 + self.phase * 10
                h.x += dx / dist * speed * dt
                h.y += dy / dist * speed * dt

            if dist < 28:
                self.state = "lost"
                self.message = "A horda te alcançou."

    def _update_difficulty(self):
        if len(self.team) >= 4:
            self.phase = 2
        if len(self.team) >= 8:
            self.phase = 3
        if len(self.team) >= 12:
            self.phase = 4

        if self.phase >= 2 and self.horde_wave < 1:
            self.horde_wave = 1
            self._spawn_horde_wave(2)
        if self.phase >= 3 and self.horde_wave < 2:
            self.horde_wave = 2
            self._spawn_horde_wave(2)
        if self.phase >= 4 and self.horde_wave < 3:
            self.horde_wave = 3
            self._spawn_horde_wave(3)

    def _convert_horde_contacts(self):
        for person in list(self.civilians):
            for h in self.horde:
                if math.hypot(person.x - h.x, person.y - h.y) < 22:
                    person.state = "horde"
                    self.horde.append(person)
                    self.civilians.remove(person)
                    self.message = "A horda recrutou alguém."
                    break

        for person in list(self.team):
            for h in self.horde:
                if math.hypot(person.x - h.x, person.y - h.y) < 22:
                    self.team.remove(person)
                    self.message = "Um recruta foi alcançado pela horda."
                    break

    def _check_exit(self):
        distance = math.hypot(self.player["x"] - self.exit["x"], self.player["y"] - self.exit["y"])
        if distance < self.exit["r"]:
            self.state = "won"
            self.message = "Você encontrou a saída!"

    def _update_player(self, dt):
        dx = 0
        dy = 0
        if self.keys["left"]:
            dx -= 1
        if self.keys["right"]:
            dx += 1
        if self.keys["up"]:
            dy -= 1
        if self.keys["down"]:
            dy += 1
        if dx or dy:
            length = math.hypot(dx, dy)
            self.facing["x"] = dx / length
            self.facing["y"] = dy / length
            self.player["x"] += (dx / length) * self.player["speed"] * dt
            self.player["y"] += (dy / length) * self.player["speed"] * dt
        self.player["x"] = max(25, min(WIDTH - 25, self.player["x"]))
        self.player["y"] = max(25, min(HEIGHT - 25, self.player["y"]))
        self._check_exit()

    def _update_confetti(self, dt):
        for burst in self.confetti:
            burst.update(dt)
        self._resolve_shot_collisions()
        self.confetti = [b for b in self.confetti if b.life > 0]

    def _draw_world(self):
        self.canvas.delete("all")
        for x in range(0, WIDTH, 80):
            self.canvas.create_line(x, 0, x, HEIGHT, fill=GRID)
        for y in range(0, HEIGHT, 80):
            self.canvas.create_line(0, y, WIDTH, y, fill=GRID)

        for room in self.rooms:
            self.canvas.create_rectangle(room["x"], room["y"], room["x"] + room["w"], room["y"] + room["h"], fill=room["fill"], outline="#3c4550")
            self.canvas.create_text(room["x"] + 14, room["y"] + 16, anchor="nw", text=room["name"], fill=TEXT, font=("Segoe UI", 12))

        self.canvas.create_oval(
            self.exit["x"] - self.exit["r"],
            self.exit["y"] - self.exit["r"],
            self.exit["x"] + self.exit["r"],
            self.exit["y"] + self.exit["r"],
            fill="#f4d35e",
            outline="#fff4b8",
            width=3,
        )
        self.canvas.create_text(self.exit["x"], self.exit["y"], text="SAÍDA", fill="#1b1d22", font=("Segoe UI", 11, "bold"))

        self.canvas.create_oval(self.player["x"] - self.player["r"], self.player["y"] - self.player["r"], self.player["x"] + self.player["r"], self.player["y"] + self.player["r"], fill=PLAYER_COLOR)

        for unit in self.civilians:
            unit.draw(self.canvas)
        for unit in self.team:
            unit.draw(self.canvas)
        for unit in self.horde:
            unit.draw(self.canvas)

        for burst in self.confetti:
            burst.draw(self.canvas)

        phase_name = ["Exploração", "Pressão", "Corrida", "Colapso"][min(self.phase - 1, 3)]
        self.canvas.create_rectangle(14, 10, 420, 96, fill="#202a38", outline="#52647a")
        self.canvas.create_text(28, 20, anchor="nw", text=f"FASE {self.phase}  {phase_name.upper()}", fill=ACCENT, font=("Segoe UI", 13, "bold"))
        self.canvas.create_text(28, 48, anchor="nw", text=f"Equipe {len(self.team)}/{self.goal}   Horda {len(self.horde)}", fill=TEXT, font=("Segoe UI", 14, "bold"))
        self.canvas.create_text(28, 73, anchor="nw", text=f"Tempo {max(0, int(self.countdown))}s   Pontos {self.upgrade_points}", fill=DIM_TEXT, font=("Segoe UI", 12))
        self.canvas.create_rectangle(WIDTH - 280, 10, WIDTH - 14, 96, fill="#202a38", outline="#52647a")
        self.canvas.create_text(WIDTH - 266, 20, anchor="nw", text="UPGRADES", fill=ACCENT, font=("Segoe UI", 11, "bold"))
        self.canvas.create_text(WIDTH - 266, 43, anchor="nw", text=f"[1] Velocidade  nv. {self.upgrades['speed']}", fill=TEXT, font=("Segoe UI", 11))
        self.canvas.create_text(WIDTH - 266, 64, anchor="nw", text=f"[2] Confete  nv. {self.upgrades['confetti']}", fill=TEXT, font=("Segoe UI", 11))
        self.canvas.create_text(24, HEIGHT - 26, anchor="nw", text=f"WASD/setas mover   ESPAÇO atirar/recrutar   Chegue à SAÍDA   R menu   |   {self.message}", fill=DIM_TEXT, font=("Segoe UI", 11))

        if self.state == "won":
            self._draw_end_screen("Crowd Party!", "Você montou a equipe e segurou a pressão.", TEAM_COLOR)
        elif self.state == "lost":
            self._draw_end_screen("A horda venceu.", "Reúna a equipe mais rápido na próxima rodada.", HORDE_COLOR)

    def _draw_end_screen(self, title, subtitle, color):
        left = WIDTH / 2 - 245
        top = HEIGHT / 2 - 105
        right = WIDTH / 2 + 245
        bottom = HEIGHT / 2 + 105
        self.canvas.create_rectangle(left, top, right, bottom, fill="#202a38", outline=color, width=3)
        self.canvas.create_text(WIDTH / 2, top + 38, text=title, fill=color, font=("Segoe UI", 30, "bold"))
        self.canvas.create_text(WIDTH / 2, top + 78, text=subtitle, fill=TEXT, font=("Segoe UI", 13))
        self.canvas.create_text(WIDTH / 2, bottom - 24, text="Pressione R para voltar ao menu", fill=DIM_TEXT, font=("Segoe UI", 11))

    def _tick(self):
        if self.state == "playing":
            dt = 0.016
            self.player_shot_timer = max(0, self.player_shot_timer - dt)
            self._update_player(dt)
            if self.state != "playing":
                self._draw_world()
                self.root.after(16, self._tick)
                return
            self._update_team(dt)
            self._advance_horde(dt)
            self._convert_horde_contacts()
            self._update_confetti(dt)
            self.horde_timer += dt
            self._update_difficulty()

            if self.horde_timer > 3:
                self.horde_timer = 0
                self._spawn_horde_wave(1 if self.phase >= 2 else 0)

            self.countdown -= dt

            if self.countdown <= 0:
                self.state = "lost"
                self.message = "Tempo acabou."

        self._draw_world()
        self.root.after(16, self._tick)


def main():
    root = tk.Tk()
    root.title("Crowd Party")
    root.geometry(f"{WIDTH}x{HEIGHT}")
    root.configure(bg=BG)
    CrowdParty(root)
    root.mainloop()


if __name__ == "__main__":
    main()
