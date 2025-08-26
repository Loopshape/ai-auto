# midi_composer.py - The AI's Sequencer Engine (v2 with better error handling)
import sys
import time

# --- CONFIGURATION ---
# IMPORTANT: Change this to the IP address of the PC running FL Studio.
PC_IP_ADDRESS = '192.168.1.100' 
PORT = 5004  # Default rtpMIDI port

# We wrap the mido import in a try/except block to give a helpful error
try:
    import mido
except ModuleNotFoundError:
    print("FATAL ERROR: The 'mido' library is not installed.")
    print("Please run: 'pip install mido'")
    sys.exit(1)

def play_sequence(outport, tempo, notes_data):
    beat_duration = 60.0 / tempo
    print(f"Tempo: {tempo} BPM, Beat Duration: {beat_duration:.4f}s")
    for note_info in notes_data:
        parts = note_info.split(',')
        if len(parts) != 2: continue
        try:
            note, duration_in_beats = int(parts[0]), float(parts[1])
            duration_in_seconds = duration_in_beats * beat_duration
            msg_on = mido.Message('note_on', note=note, velocity=100)
            print(f"  -> Note ON: {note}, Duration: {duration_in_seconds:.4f}s")
            outport.send(msg_on)
            time.sleep(duration_in_seconds)
            msg_off = mido.Message('note_off', note=note)
            print(f"  -> Note OFF: {note}")
            outport.send(msg_off)
        except ValueError:
            print(f"Warning: Could not parse note data '{note_info}'. Skipping.")
            continue

def main():
    if len(sys.argv) < 2 or not sys.argv[1].startswith('sequence'):
        print("Usage: python midi_composer.py \"sequence tempo=[bpm] notes=[note],[duration];...\"")
        sys.exit(1)
    full_command = " ".join(sys.argv[1:])
    try:
        params = dict(part.split('=') for part in full_command.split(' ')[1:])
        tempo = int(params['tempo'])
        notes_data = params['notes'].split(';')
        
        # This is the main try/except block for MIDI connection
        try:
            with mido.open_output(f'rtpmidi:{PC_IP_ADDRESS}:{PORT}') as outport:
                play_sequence(outport, tempo, notes_data)
        except ModuleNotFoundError as e:
            # --- THIS IS THE NEW, SMARTER ERROR CATCH ---
            if 'rtmidi' in str(e):
                print(f"FATAL ERROR: The low-level MIDI library is missing.")
                print(f"Please run: 'pip install python-rtmidi --force-reinstall'")
            else:
                print(f"FATAL ERROR: A required Python module is missing: {e}")
                print(f"Please try running: 'pip install mido python-rtpmidi python-rtmidi --force-reinstall'")
            sys.exit(1)
        except (OSError, IOError) as e:
            print(f"MIDI CONNECTION ERROR: {e}")
            print(f"Could not connect to {PC_IP_ADDRESS}:{PORT}. Is rtpMIDI running on the PC?")
            sys.exit(1)

    except Exception as e:
        print(f"Error parsing AI command or sending MIDI: {e}")
        print("The AI may have provided a malformed sequence.")
        sys.exit(1)

if __name__ == "__main__":
    main()
