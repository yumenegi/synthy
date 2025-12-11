from mido import MidiFile
import time
import serial
import serial.tools.list_ports
import math
from patch import Patch, Channel
from engine import Engine
import engine
import curses
from collections import deque



def draw_dashboard(win, channel_status):
    win.erase()
    win.border()
    win.addstr(0, 2, " [ SYNTH DASHBOARD ] ", curses.color_pair(1) | curses.A_BOLD)
    
    for i in range(16):
        # Safety check to keep within window bounds
        if i + 1 < win.getmaxyx()[0] - 1:
            status = channel_status[i]
            # Color active channels green, inactive grey
            attr = curses.color_pair(2) if "Note:" in status else curses.color_pair(3)
            win.addstr(i + 1, 2, f"CH{i+1:02}: {status}", attr)
    win.refresh()

def draw_tracker(win, history):
    win.erase()
    win.border()
    win.addstr(0, 2, " [ TRACKER VIEW ] ", curses.color_pair(1) | curses.A_BOLD)

    # Draw Header
    header = "  " + " ".join([f"{i+1:02}  " for i in range(16)])
    win.addstr(1, 1, header, curses.color_pair(4) | curses.A_UNDERLINE)

    rows, cols = win.getmaxyx()
    
    # Draw history from bottom up
    # We slice the history to fit the window height (minus border and header)
    visible_lines = rows - 3
    
    # Get the last N items
    view_data = list(history)[-visible_lines:]

    for r_idx, row_data in enumerate(view_data):
        # Construct the row string: "  C-4 ... F#3 ..."
        line_str = "  "
        for ch_note in row_data:
            line_str += f"{ch_note:<3}  "
        
        try:
            # +2 accounts for border and header
            win.addstr(r_idx + 2, 1, line_str, curses.color_pair(3)) 
        except curses.error:
            pass
            
    win.refresh()

# Main
def main(stdscr):
    mid = MidiFile('rydeen.mid')

    output_device = serial.Serial("COM9", baudrate=115200)
    audio_engine = Engine(output_device)

    default_patch = Patch("default", [2, 1], 0)
    bass1 = Patch("bass1", [3], 0)
    jab1 = Patch("jab1", [1], 0, True, 3, 15)
    lead1 = Patch("lead1", [2, 4], 0)
    lead2 = Patch("lead2", [6], 0, True, 7, 20)
    harm1 = Patch("harm1", [2], 0)
    brass1 = Patch("brass1", [6], 0)
    square1 = Patch("square1", [3], 0)
    drum = Patch("drum", [0, 1, 6], 1)
    tom = Patch("tom", [0], 1)


    patches = [default_patch] * 16
    patches[1] = bass1
    patches[2] = jab1
    patches[3] = lead1
    patches[4] = lead1
    patches[5] = lead2
    patches[6] = brass1
    patches[7] = harm1
    patches[8] = square1
    patches[9] = drum
    patches[10] = drum
    patches[11] = tom
    patches[12] = tom
    patches[13] = harm1

    channels = []
    for i in range(16):
        channels.append(Channel(i, patches[i]))

    # 1. Curses Configuration
    curses.curs_set(0) # Hide cursor
    curses.start_color()
    curses.use_default_colors()

    # Colors: 1=Cyan, 2=Green(Active), 3=White(Dim), 4=Yellow(Header)
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_WHITE, -1)
    curses.init_pair(4, curses.COLOR_YELLOW, -1)

    # 2. Window Setup
    rows, cols = stdscr.getmaxyx()
    # Split screen: Top 18 lines for Dashboard, Rest for Tracker
    dash_height = 19
    tracker_height = rows - dash_height

    win_dash = curses.newwin(dash_height, cols, 0, 0)
    win_track = curses.newwin(tracker_height, cols, dash_height, 0)

    # 3. Data State
    channel_status = ["--"] * 16

    # Tracker state: A deque representing rows of the tracker
    # Each row is a list of 16 strings (e.g., ["C-4", "...", "..."])
    tracker_history = deque(maxlen=tracker_height)
    # Fill with empty data initially
    for _ in range(tracker_height):
        tracker_history.append([".. "] * 16)
        
    # Current active notes (to persist in tracker view if holding)
    active_tracker_row = [".. "] * 16 

    # 4. Silence Synth
    # for i in range(256):
        # send_synth_cmd(0, i, 0, 0, 0, 0)

    # 5. Play Loop
    start_time = time.time()

    try:
        for msg in mid:
            if msg.time > 0:
                if msg.time > 0.02: 
                    tracker_history.append(list(active_tracker_row))
                    draw_tracker(win_track, tracker_history)
                time.sleep(msg.time)
            if not msg.is_meta and hasattr(msg, 'channel'):
                ch = msg.channel
                if (ch >= 16):
                    continue
                if msg.type == 'note_on' and msg.velocity > 0:
                    note = msg.note
                    name = engine.note_to_name(msg.note)
                    freq = engine.midi_to_freq(msg.note)
                    strd = engine.freq_to_stride(44100, freq)
                    active_tracker_row[ch] = name
                    channel_status[ch] = f"Mid: {note:3} || Note: {name:4} || Freq: {int(freq):05} || Stride: {strd:10}"
                    audio_engine.play_note(channels[ch], note, 1)
                elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                    note = msg.note
                    audio_engine.play_note(channels[ch], note, 0)
                    active_tracker_row[ch] = ".. "
                    channel_status[ch] = "--"
                if msg.type == 'program_change':
                    channel_status[ch] = f"Switched to Instrument ID: {msg.program}"
            

            draw_dashboard(win_dash, channel_status)

            win_dash.nodelay(True)
            k = win_dash.getch()
            if k == ord('q'):
                break


    except KeyboardInterrupt:
        # Clean exit so the terminal cursor isn't stuck in the middle of the block
        print("\n" * 16)
        print("Stopped.")

curses.wrapper(main)