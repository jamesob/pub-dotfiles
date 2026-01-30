#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pyqt5",
# ]
# ///
#!/usr/bin/env python3
import hashlib
import os
import re
import sys
import subprocess
import tempfile
import urllib.request
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout,
    QHBoxLayout, QPushButton, QLabel, QSlider,
    QSizePolicy, QGridLayout, QScrollArea, QFrame,
)
from PyQt5.QtCore import Qt, QTimer, QThread, pyqtSignal
from PyQt5.QtGui import QFont, QPixmap
from PyQt5.QtWidgets import QStyleOptionSlider, QStyle

ART_CACHE_DIR = os.path.join(
    tempfile.gettempdir(), "media-touchpad-art"
)
ART_SIZE = 120


def get_players():
    """Return list of playerctl player names."""
    try:
        result = subprocess.run(
            ["playerctl", "-l"],
            capture_output=True, text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip().splitlines()
    except Exception:
        pass
    return []


def get_all_metadata():
    """Parse `playerctl -a metadata` into a dict keyed by
    player name. Each value is a dict of metadata fields."""
    try:
        result = subprocess.run(
            ["playerctl", "-a", "metadata"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            return {}
    except Exception:
        return {}

    players: dict[str, dict[str, str]] = {}
    for line in result.stdout.splitlines():
        parts = line.split(None, 2)
        if len(parts) < 2:
            continue
        name = parts[0]
        key = parts[1]
        value = parts[2] if len(parts) > 2 else ""
        # Strip namespace prefix (e.g. mpris:, xesam:)
        short = key.split(":", 1)[-1] if ":" in key else key
        players.setdefault(name, {})[short] = value
    return players


def get_player_status(player_name):
    """Return playerctl status string for a player."""
    try:
        r = subprocess.run(
            ["playerctl", "-p", player_name, "status"],
            capture_output=True, text=True,
        )
        return r.stdout.strip().lower()
    except Exception:
        return ""


def fetch_art_path(url):
    """Return a local file path for album art URL.
    Handles file:// and http(s):// with disk caching."""
    if not url:
        return None
    if url.startswith("file://"):
        path = url[7:]
        return path if os.path.isfile(path) else None

    os.makedirs(ART_CACHE_DIR, exist_ok=True)
    h = hashlib.md5(url.encode()).hexdigest()
    ext = ".jpg"
    if ".png" in url:
        ext = ".png"
    cached = os.path.join(ART_CACHE_DIR, h + ext)
    if os.path.isfile(cached):
        return cached
    try:
        urllib.request.urlretrieve(url, cached)
        return cached
    except Exception:
        return None


class ArtFetcher(QThread):
    """Background thread to fetch album art."""
    finished = pyqtSignal(str, str)  # player_name, path

    def __init__(self, player_name, url):
        super().__init__()
        self.player_name = player_name
        self.url = url

    def run(self):
        path = fetch_art_path(self.url)
        self.finished.emit(
            self.player_name, path or ""
        )


def _parse_sink_inputs():
    """Parse pactl sink inputs into a list of dicts with
    id, binary, media_name, volume, muted, corked."""
    try:
        result = subprocess.run(
            ["pactl", "list", "sink-inputs"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            return []
    except Exception:
        return []

    entries = []
    cur = None
    for line in result.stdout.splitlines():
        m = re.match(r"Sink Input #(\d+)", line)
        if m:
            if cur:
                entries.append(cur)
            cur = {
                "id": m.group(1), "binary": "",
                "media_name": "", "volume": 100,
                "muted": False, "corked": False,
            }
            continue
        if cur is None:
            continue
        stripped = line.strip()
        if stripped.startswith("Volume:"):
            vm = re.search(r"(\d+)%", stripped)
            if vm:
                cur["volume"] = int(vm.group(1))
        elif stripped.startswith(("Muted:", "Mute:")):
            cur["muted"] = "yes" in stripped.lower()
        elif stripped.startswith(("Corked:", "Cork:")):
            cur["corked"] = "yes" in stripped.lower()
        elif stripped.startswith(
            "application.process.binary"
        ):
            cur["binary"] = (
                stripped.split("=", 1)[-1]
                .strip().strip('"')
            )
        elif stripped.startswith("media.name"):
            cur["media_name"] = (
                stripped.split("=", 1)[-1]
                .strip().strip('"')
            )
    if cur:
        entries.append(cur)
    return entries


def get_sink_inputs_for_binary(binary):
    """Return list of (sink_input_id, volume%, muted) for
    all PulseAudio sink inputs whose binary starts with the
    given name."""
    binary_lower = binary.lower()
    return [
        (si["id"], si["volume"], si["muted"])
        for si in _parse_sink_inputs()
        if si["binary"].lower().startswith(binary_lower)
    ]


def get_active_media_name_for_binary(binary):
    """Return the media_name from the active (uncorked)
    pactl sink input matching the given binary, or None."""
    binary_lower = binary.lower()
    for si in _parse_sink_inputs():
        if (
            si["binary"].lower().startswith(binary_lower)
            and not si["corked"]
            and si["media_name"]
        ):
            return si["media_name"]
    return None


class FaderSlider(QSlider):
    """QSlider that jumps to the clicked position."""

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            opt = QStyleOptionSlider()
            self.initStyleOption(opt)
            groove = self.style().subControlRect(
                QStyle.CC_Slider, opt,
                QStyle.SC_SliderGroove, self,
            )
            handle = self.style().subControlRect(
                QStyle.CC_Slider, opt,
                QStyle.SC_SliderHandle, self,
            )
            if self.orientation() == Qt.Horizontal:
                pos = event.x()
                span = groove.width() - handle.width()
                offset = groove.x() + handle.width() // 2
                val = QStyle.sliderValueFromPosition(
                    self.minimum(), self.maximum(),
                    pos - offset, span,
                )
            else:
                pos = event.y()
                span = groove.height() - handle.height()
                offset = groove.y() + handle.height() // 2
                val = QStyle.sliderValueFromPosition(
                    self.minimum(), self.maximum(),
                    pos - offset, span,
                    upsideDown=True,
                )
            self.setValue(val)
            event.accept()
        super().mousePressEvent(event)


class PlayerRow(QFrame):
    """A row for a single playerctl player with album art."""

    IDLE_FRAME = (
        "PlayerRow {"
        "  background: transparent;"
        "  border-left: 6px solid transparent;"
        "  margin-left: 10px; padding-top: 6px; padding-bottom: 6px;"
        "  border-bottom: 1px solid #3b4252;"
        "  padding-left: 20px;"
        "}"
    )
    PLAYING_FRAME = (
        "PlayerRow {"
        "  background: rgba(163, 190, 140, 15);"
        "  border-left: 6px solid #a3be8c;"
        "  margin-left: 10px; padding-top: 6px; padding-bottom: 6px;"
        "  border-bottom: 1px solid #3b4252;"
        "  padding-left: 20px;"
        "}"
    )
    ROW_BTN = (
        "QPushButton {"
        "  min-width: 0; min-height: 0; padding: 4px;"
        "  font-size: 15pt; border-radius: 6px;"
        "  background-color: #3b4252; color: #eceff4;"
        "}"
        "QPushButton:hover {"
        "  background-color: #434c5e;"
        "}"
    )
    ROW_BTN_PLAYING = (
        "QPushButton {"
        "  min-width: 0; min-height: 0; padding: 4px;"
        "  font-size: 15pt; border-radius: 6px;"
        "  background-color: #3b4252; color: #eceff4;"
        "  border: 2px solid #a3be8c;"
        "}"
        "QPushButton:hover {"
        "  background-color: #434c5e;"
        "}"
    )
    ROW_SLIDER_STYLE = (
        "QSlider::groove:horizontal {"
        "  height: 6px; background: #4c566a;"
        "  border-radius: 3px;"
        "}"
        "QSlider::sub-page:horizontal {"
        "  background: #5e81ac;"
        "  border-radius: 3px;"
        "}"
        "QSlider::handle:horizontal {"
        "  background: qlineargradient("
        "    x1:0, y1:0, x2:0, y2:1,"
        "    stop:0 #555e6e, stop:0.42 #555e6e,"
        "    stop:0.43 #8090a0, stop:0.57 #8090a0,"
        "    stop:0.58 #555e6e, stop:1 #555e6e);"
        "  width: 10px; height: 28px;"
        "  margin: -12px 0;"
        "  border: 1px solid #3b4252;"
        "  border-radius: 2px;"
        "}"
    )

    def __init__(self, player_name, parent_controller):
        super().__init__()
        self.player_name = player_name
        self.controller = parent_controller
        self._updating_slider = False
        self._is_playing = False
        self._current_art_url = ""
        self._art_fetcher = None
        self.setStyleSheet(self.IDLE_FRAME)

        # Main horizontal layout: [art] [info+slider] [btns]
        hbox = QHBoxLayout(self)
        hbox.setContentsMargins(6, 8, 6, 8)
        hbox.setSpacing(10)

        # Album art label
        self.art_label = QLabel()
        self.art_label.setFixedSize(ART_SIZE, ART_SIZE)
        self.art_label.setStyleSheet(
            "background: #3b4252; border-radius: 4px;"
        )
        self.art_label.setAlignment(Qt.AlignCenter)
        hbox.addWidget(self.art_label)

        # Middle: title/artist + album + slider
        mid = QVBoxLayout()
        mid.setSpacing(2)

        self.title_label = QLabel(player_name)
        self.title_label.setFont(QFont("Sans", 11))
        self.title_label.setStyleSheet(
            "color: #eceff4;"
        )
        self.title_label.setWordWrap(False)
        self.title_label.setSizePolicy(
            QSizePolicy.Ignored, QSizePolicy.Minimum
        )
        mid.addWidget(self.title_label)

        self.artist_label = QLabel("")
        self.artist_label.setFont(QFont("Sans", 9))
        self.artist_label.setStyleSheet(
            "color: #81a1c1;"
        )
        self.artist_label.setWordWrap(False)
        self.artist_label.setSizePolicy(
            QSizePolicy.Ignored, QSizePolicy.Minimum
        )
        mid.addWidget(self.artist_label)

        self.album_label = QLabel("")
        self.album_label.setFont(QFont("Sans", 8))
        self.album_label.setStyleSheet(
            "color: #8fbcbb;"
        )
        self.album_label.setWordWrap(False)
        self.album_label.setSizePolicy(
            QSizePolicy.Ignored, QSizePolicy.Minimum
        )
        mid.addWidget(self.album_label)

        self.vol_slider = FaderSlider(Qt.Horizontal)
        self.vol_slider.setRange(0, 100)
        self.vol_slider.setValue(100)
        self.vol_slider.setStyleSheet(self.ROW_SLIDER_STYLE)
        self.vol_slider.setMinimumHeight(24)
        self.vol_slider.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.vol_slider.valueChanged.connect(
            self.on_slider_changed
        )
        mid.addWidget(self.vol_slider)

        hbox.addLayout(mid, stretch=3)

        # Buttons column (8% extra left margin)
        btn_box = QVBoxLayout()
        btn_box.setContentsMargins(36, 0, 0, 0)
        btn_box.setSpacing(4)
        btn_font = QFont("Sans", 15)

        self.pause_btn = QPushButton("⏸")
        self.pause_btn.setFont(btn_font)
        self.pause_btn.setStyleSheet(self.ROW_BTN)
        self.pause_btn.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.pause_btn.clicked.connect(
            self.toggle_play_pause
        )

        self.next_btn = QPushButton("⏭")
        self.next_btn.setFont(btn_font)
        self.next_btn.setStyleSheet(self.ROW_BTN)
        self.next_btn.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.next_btn.clicked.connect(self.next_track)

        self.mute_btn = QPushButton("🔊")
        self.mute_btn.setFont(btn_font)
        self.mute_btn.setStyleSheet(self.ROW_BTN)
        self.mute_btn.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.mute_btn.clicked.connect(
            self.toggle_player_mute
        )

        btn_row = QHBoxLayout()
        btn_row.setSpacing(4)
        btn_row.addWidget(self.pause_btn)
        btn_row.addWidget(self.next_btn)
        btn_row.addWidget(self.mute_btn)
        btn_box.addLayout(btn_row)

        hbox.addLayout(btn_box, stretch=2)

        self.setMinimumHeight(ART_SIZE + 20)

    @property
    def _binary(self):
        return self.player_name.split(".")[0]

    @property
    def _is_browser(self):
        base = self._binary.lower()
        return any(
            b in base
            for b in ("firefox", "chromium", "chrome")
        )

    def _pa_sink_ids(self):
        return get_sink_inputs_for_binary(self._binary)

    def on_slider_changed(self, value):
        if self._updating_slider:
            return
        if self._is_browser:
            for sid, _, _ in self._pa_sink_ids():
                subprocess.run(
                    ["pactl", "set-sink-input-volume",
                     sid, f"{value}%"]
                )
        else:
            vol = value / 100.0
            subprocess.run(
                ["playerctl", "-p", self.player_name,
                 "volume", str(vol)]
            )

    def _active_browser_instance(self):
        """For browsers, find the playerctl instance that is
        actually Playing (not just any instance)."""
        binary_low = self._binary.lower()
        for p in get_players():
            if p.split(".")[0].lower() == binary_low:
                if get_player_status(p) == "playing":
                    return p
        return self.player_name

    def _schedule_refresh(self):
        """Trigger a refresh after a short delay to let
        the player state settle."""
        QTimer.singleShot(
            150, self.controller.refresh_player_rows
        )

    def toggle_play_pause(self):
        if self._is_browser:
            target = self._active_browser_instance()
        else:
            target = self.player_name
        subprocess.run(
            ["playerctl", "-p", target, "play-pause"]
        )
        self._schedule_refresh()

    def next_track(self):
        if self._is_browser:
            target = self._active_browser_instance()
        else:
            target = self.player_name
        subprocess.run(
            ["playerctl", "-p", target, "next"]
        )
        self._schedule_refresh()

    def toggle_player_mute(self):
        if self._is_browser:
            for sid, _, _ in self._pa_sink_ids():
                subprocess.run(
                    ["pactl", "set-sink-input-mute",
                     sid, "toggle"]
                )
        else:
            saved = self.controller.saved_volumes
            try:
                result = subprocess.run(
                    ["playerctl", "-p", self.player_name,
                     "volume"],
                    capture_output=True, text=True,
                )
                current = float(result.stdout.strip())
            except (ValueError, Exception):
                return
            if current > 0.01:
                saved[self.player_name] = current
                subprocess.run(
                    ["playerctl", "-p", self.player_name,
                     "volume", "0"]
                )
            else:
                restore = saved.get(
                    self.player_name, 1.0
                )
                subprocess.run(
                    ["playerctl", "-p", self.player_name,
                     "volume", str(restore)]
                )
        self._schedule_refresh()

    def update_art(self, art_url):
        """Kick off album art loading if URL changed."""
        if art_url == self._current_art_url:
            return
        self._current_art_url = art_url
        if not art_url:
            self.art_label.setPixmap(QPixmap())
            return
        # file:// URLs can be loaded directly
        if art_url.startswith("file://"):
            path = art_url[7:]
            self._set_art_pixmap(path)
            return
        # HTTP: fetch in background thread
        self._art_fetcher = ArtFetcher(
            self.player_name, art_url
        )
        self._art_fetcher.finished.connect(
            self._on_art_fetched
        )
        self._art_fetcher.start()

    def _on_art_fetched(self, player_name, path):
        if player_name == self.player_name and path:
            self._set_art_pixmap(path)

    def _set_art_pixmap(self, path):
        pm = QPixmap(path)
        if not pm.isNull():
            self.art_label.setPixmap(
                pm.scaled(
                    ART_SIZE, ART_SIZE,
                    Qt.KeepAspectRatio,
                    Qt.SmoothTransformation,
                )
            )

    def refresh(self, meta):
        """Update from metadata dict and playerctl status."""
        title = meta.get("title", "")
        artist = meta.get("artist", "")
        album = meta.get("album", "")
        art_url = meta.get("artUrl", "")

        # Browsers: pull title from the active pactl sink
        # input since playerctl metadata is unreliable
        pa_title = None
        if self._is_browser:
            pa_title = get_active_media_name_for_binary(
                self._binary
            )
            if pa_title:
                title = pa_title

        self.title_label.setText(
            title or self.player_name
        )
        self.artist_label.setText(artist)
        self.album_label.setText(album)
        self.album_label.setVisible(bool(album))

        self.update_art(art_url)

        status = get_player_status(self.player_name)
        playing = status == "playing"
        self.pause_btn.setText(
            "⏸" if playing else "▶"
        )

        if playing != self._is_playing:
            self._is_playing = playing
            self.setStyleSheet(
                self.PLAYING_FRAME if playing
                else self.IDLE_FRAME
            )
            self.pause_btn.setStyleSheet(
                self.ROW_BTN_PLAYING if playing
                else self.ROW_BTN
            )

        self._refresh_volume()

    def _refresh_volume(self):
        pct = None
        muted = False

        if self._is_browser:
            sinks = self._pa_sink_ids()
            if sinks:
                pct = max(v for _, v, _ in sinks)
                muted = all(m for _, _, m in sinks)
        else:
            try:
                result = subprocess.run(
                    ["playerctl", "-p", self.player_name,
                     "volume"],
                    capture_output=True, text=True,
                )
                vol = float(result.stdout.strip())
                pct = int(vol * 100)
                muted = vol < 0.01
            except (ValueError, Exception):
                pass

        if pct is not None:
            self.mute_btn.setText(
                "🔇" if muted else "🔊"
            )
            self._updating_slider = True
            self.vol_slider.setValue(pct)
            self._updating_slider = False


class MediaController(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Media Controller")
        self.resize(450, 500)

        self.saved_volumes: dict[str, float] = {}
        self.player_rows: dict[str, PlayerRow] = {}

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(10, 10, 10, 10)
        main_layout.setSpacing(10)

        # --- Per-player rows in a scroll area ---
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(
            Qt.ScrollBarAlwaysOff
        )
        self.players_container = QWidget()
        self.players_container.setObjectName(
            "playersContainer"
        )
        self.players_layout = QVBoxLayout(
            self.players_container
        )
        self.players_layout.setContentsMargins(0, 0, 0, 0)
        self.players_layout.setSpacing(20)
        self.players_layout.addStretch()
        scroll.setWidget(self.players_container)
        main_layout.addWidget(scroll, 5)

        # --- Global controls grid ---
        grid_layout = QGridLayout()
        grid_layout.setSpacing(8)

        self.mute_button = QPushButton("🔊")
        self.mute_button.setFont(QFont("Sans", 14))
        self.mute_button.clicked.connect(self.toggle_mute)
        self.mute_button.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.mute_button.setMinimumHeight(50)
        grid_layout.addWidget(self.mute_button, 0, 0)

        self.switch_input_button = QPushButton("Switch Input")
        self.switch_input_button.setFont(QFont("Sans", 10))
        self.switch_input_button.clicked.connect(
            self.toggle_audio_sink
        )
        self.switch_input_button.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.switch_input_button.setMinimumHeight(50)
        grid_layout.addWidget(
            self.switch_input_button, 0, 1, 1, 2
        )

        vol_down_button = QPushButton("🔈")
        vol_down_button.setFont(QFont("Sans", 14))
        vol_down_button.clicked.connect(self.volume_down)
        vol_down_button.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        vol_down_button.setMinimumHeight(50)
        grid_layout.addWidget(vol_down_button, 1, 0)

        self.volume_slider = FaderSlider(Qt.Horizontal)
        self.volume_slider.setRange(0, 100)
        self.volume_slider.setValue(50)
        self.volume_slider.valueChanged.connect(
            self.set_volume
        )
        self.volume_slider.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.volume_slider.setMinimumHeight(30)
        grid_layout.addWidget(self.volume_slider, 1, 1)

        vol_up_button = QPushButton("🔊")
        vol_up_button.setFont(QFont("Sans", 14))
        vol_up_button.clicked.connect(self.volume_up)
        vol_up_button.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        vol_up_button.setMinimumHeight(50)
        grid_layout.addWidget(vol_up_button, 1, 2)

        grid_layout.setColumnStretch(0, 1)
        grid_layout.setColumnStretch(1, 1)
        grid_layout.setColumnStretch(2, 1)

        main_layout.addLayout(grid_layout, 2)

        self.setMinimumSize(300, 250)

        self.setStyleSheet("""
            QMainWindow {
                background-color: #2e3440;
            }
            QLabel {
                color: #eceff4;
            }
            QPushButton {
                background-color: #3b4252;
                color: #eceff4;
                border-radius: 8px;
                padding: 10px;
                min-width: 50px;
                min-height: 50px;
                font-size: 16pt;
            }
            QPushButton:hover {
                background-color: #434c5e;
            }
            QSlider::groove:horizontal {
                height: 6px;
                background: #4c566a;
                margin: 2px 0;
                border-radius: 3px;
            }
            QSlider::sub-page:horizontal {
                background: #5e81ac;
                border-radius: 3px;
            }
            QSlider::handle:horizontal {
                background: qlineargradient(
                    x1:0, y1:0, x2:0, y2:1,
                    stop:0 #555e6e, stop:0.42 #555e6e,
                    stop:0.43 #8090a0, stop:0.57 #8090a0,
                    stop:0.58 #555e6e, stop:1 #555e6e);
                width: 14px;
                height: 34px;
                margin: -14px 0;
                border: 1px solid #3b4252;
                border-radius: 2px;
            }
            QScrollArea {
                background: transparent;
                border: none;
            }
            #playersContainer {
                background: transparent;
            }
        """)

        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self.periodic_update)
        self.update_timer.start(750)

        self.update_volume_slider()
        self.refresh_player_rows()
        self.update_input_button_text()
        self.update_mute_button_state()

    # --- Player row management ---

    def refresh_player_rows(self):
        all_meta = get_all_metadata()
        players = get_players()

        # Use playerctl players as source of truth
        wanted = set(players)
        existing = set(self.player_rows.keys())

        # Remove gone rows
        for name in existing - wanted:
            row = self.player_rows.pop(name)
            self.players_layout.removeWidget(row)
            row.deleteLater()

        # Add/update rows
        for name in players:
            if name not in self.player_rows:
                row = PlayerRow(name, self)
                idx = self.players_layout.count() - 1
                self.players_layout.insertWidget(idx, row)
                self.player_rows[name] = row
            # Metadata keys may be short names (e.g.
            # "firefox") while playerctl -l returns full
            # instance names (e.g. "firefox.instance123")
            base = name.split(".")[0]
            meta = all_meta.get(name, all_meta.get(
                base, {}
            ))
            self.player_rows[name].refresh(meta)

    def periodic_update(self):
        self.refresh_player_rows()
        self.update_input_button_text()
        self.update_mute_button_state()

    # --- Global controls ---

    def toggle_mute(self):
        try:
            subprocess.run(
                ["pactl", "set-sink-mute",
                 "@DEFAULT_SINK@", "toggle"]
            )
            self.update_mute_button_state()
        except Exception as e:
            print(f"Error toggling mute: {e}")

    def update_mute_button_state(self):
        try:
            result = subprocess.run(
                ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                if "yes" in result.stdout.lower():
                    self.mute_button.setText("🔇")
                else:
                    self.mute_button.setText("🔊")
        except Exception as e:
            print(f"Error updating mute button state: {e}")

    def volume_up(self):
        subprocess.run(
            ["pactl", "set-sink-volume",
             "@DEFAULT_SINK@", "+5%"]
        )
        self.update_volume_slider()

    def volume_down(self):
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"])
        self.update_volume_slider()

    def set_volume(self, value):
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{value}%"])

    def update_volume_slider(self):
        try:
            result = subprocess.run(
                ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                output = result.stdout
                if "%" in output:
                    vol_str = output.split("%")[0].split()[-1]
                    try:
                        self.volume_slider.setValue(
                            int(vol_str)
                        )
                    except ValueError:
                        pass
        except Exception as e:
            print(f"Error updating volume: {e}")

    def toggle_audio_sink(self):
        try:
            result = subprocess.run(
                ["pactl", "list", "sinks", "short"],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                sinks = result.stdout.strip().split('\n')
                modi_sink = None
                fulla_sink = None

                for sink in sinks:
                    if "Modi" in sink:
                        modi_sink = sink.split('\t')[0]
                    elif "Fulla" in sink:
                        fulla_sink = sink.split('\t')[0]

                default_result = subprocess.run(
                    ["pactl", "get-default-sink"],
                    capture_output=True, text=True,
                )
                current_sink = default_result.stdout.strip()

                if modi_sink and fulla_sink:
                    if "Modi" in current_sink:
                        subprocess.run(
                            ["pactl", "set-default-sink",
                             fulla_sink]
                        )
                    else:
                        subprocess.run(
                            ["pactl", "set-default-sink",
                             modi_sink]
                        )
                    self.move_streams_to_default_sink()

                self.update_volume_slider()
                self.update_input_button_text()
                self.update_mute_button_state()
        except Exception as e:
            print(f"Error toggling audio sink: {e}")

    def move_streams_to_default_sink(self):
        try:
            default_sink = subprocess.run(
                ["pactl", "get-default-sink"],
                capture_output=True, text=True,
            ).stdout.strip()

            streams = subprocess.run(
                ["pactl", "list", "sink-inputs", "short"],
                capture_output=True, text=True,
            )
            if (
                streams.returncode == 0
                and streams.stdout.strip()
            ):
                for stream in (
                    streams.stdout.strip().split('\n')
                ):
                    stream_id = stream.split('\t')[0]
                    subprocess.run(
                        ["pactl", "move-sink-input",
                         stream_id, default_sink]
                    )
        except Exception as e:
            print(f"Error moving streams: {e}")

    def update_input_button_text(self):
        try:
            default_result = subprocess.run(
                ["pactl", "get-default-sink"],
                capture_output=True, text=True,
            )
            current_sink = default_result.stdout.strip()
            if "Modi" in current_sink:
                self.switch_input_button.setText(
                    "Switch to phones"
                )
            elif "Fulla" in current_sink:
                self.switch_input_button.setText(
                    "Switch to speakers"
                )
            else:
                self.switch_input_button.setText(
                    "Switch Input"
                )
        except Exception:
            self.switch_input_button.setText("Switch Input")


def debug_dump():
    """Print raw playerctl metadata for debugging."""
    print("=" * 60)
    print("PLAYERCTL PLAYERS (playerctl -l)")
    print("=" * 60)
    raw = get_players()
    if not raw:
        print("  (none)")
    for p in raw:
        print(f"\n  {p}")
        print(f"    status: {get_player_status(p)}")

    print(f"\n  Total: {len(raw)}")

    print("\n" + "=" * 60)
    print("METADATA (playerctl -a metadata)")
    print("=" * 60)
    all_meta = get_all_metadata()
    for name, meta in all_meta.items():
        print(f"\n  {name}:")
        for k, v in meta.items():
            print(f"    {k:16s}: {v}")

    if not all_meta:
        print("  (none)")
    print()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "debug":
        debug_dump()
        sys.exit(0)

    app = QApplication(sys.argv)
    window = MediaController()
    window.show()
    sys.exit(app.exec_())
