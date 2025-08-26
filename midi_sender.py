# midi_sender.py - The MIDI Engine for our AI Controller
import mido
import sys
import os

# --- CONFIGURATION ---
# IMPORTANT: Change this to the IP address of the PC running FL Studio.
PC_IP_ADDRESS = '192.168.1.100' 
PORT = 5004  # This is the default port for rtpMIDI

def main():
    if len(sys.argv) < 2:
        print("Usage: python midi_sender.py <command> [args...]")
        print("Commands: note_on, note_off, cc (control_change)")
        sys.exit(1)

    command = sys.argv[1]
    args = sys.argv[2:]

    try:
        # Connect to the rtpMIDI port on the PC
        with mido.open_output(f'rtpmidi:{PC_IP_ADDRESS}:{PORT}') as outport:
            msg = None
            if command == 'note_on' and len(args) == 2:
                note, velocity = int(args[0]), int(args[1])
                msg = mido.Message('note_on', note=note, velocity=velocity)
            elif command == 'note_off' and len(args) == 1:
                note = int(args[0])
                msg = mido.Message('note_off', note=note)
            elif command in ('cc', 'control_change') and len(args) == 2:
                control, value = int(args[0]), int(args[1])
                msg = mido.Message('control_change', control=control, value=value)
            
            if msg:
                print(f"Sending MIDI message: {msg}")
                outport.send(msg)
            else:
                print(f"Error: Invalid command or arguments for '{command}'")

    except Exception as e:
        print(f"An error occurred: {e}")
        print("Could not connect to the MIDI port. Is rtpMIDI running on the PC?")

if __name__ == "__main__":
    main()
