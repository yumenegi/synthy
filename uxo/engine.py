from mido import MidiFile
import time
import serial
import serial.tools.list_ports
import math
from patch import Patch, Channel

SAMPLING_RATE = 44100

def note_to_name(note_number):
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    octave = note_number // 12 - 1
    return f"{notes[note_number % 12]}{octave}"

def midi_to_freq(note_number):
    return 440.0 * (2.0 ** ((note_number - 69) / 12.0))

def freq_to_stride(freq, sr = SAMPLING_RATE):
    TWO_POW_32 = 4294967296
    
    stride = (freq * TWO_POW_32) / sr
    
    return int(stride)

import math

def calculate_unison_strides(center_freq_hz, detune_base_cents, voices) -> list[int]:
    if voices <= 1:
        return [center_freq_hz]
    freqs = []
    for i in range(voices):
        fraction = i / (voices - 1)
        factor = (fraction * 2.0) - 1.0 # +-1
        cents_offset = factor * detune_base_cents
        multiplier = math.pow(2, cents_offset / 1200.0)
        freqs.append(freq_to_stride(center_freq_hz * multiplier))

    return freqs

class Engine:
    def __init__(self, device: serial.Serial):
        self.device = device
        self.reset()

    def send_serial(self, data):
        if self.device:
            self.device.write(data)
    
    def reset(self):
        for i in range(256):
            self.send_serial(bytes((0xDEADBEEF).to_bytes(4)))
            self.send_serial(bytes(((0).to_bytes(4)) + i.to_bytes(1) + ((0).to_bytes(4)) + (int(0).to_bytes(1)) + (int(0).to_bytes(1)) + (int(0).to_bytes(1))))
    
    # instrument include envelope info
    def play_note(self, channel: Channel, note, key_on):
        hw_indices = None
        if key_on:
            hw_indices = channel.allocate_voice(note)
        else:
            hw_indices = channel.release_voice(note)

        if hw_indices is None:
            return

        patch = channel.get_patch()
        waves = patch.getWaveforms()
        unison = patch.isUnison()
        envelope = patch.getEnvelope()
        freq = midi_to_freq(note)

        if not unison:
            stride = freq_to_stride(freq)
            for index, wave in zip(hw_indices, waves):
                self.send_serial(bytes((0xDEADBEEF).to_bytes(4)))
                self.send_serial(bytes(stride.to_bytes(4) + 
                                    index.to_bytes(1) + 
                                    wave.to_bytes(4) + 
                                    envelope.to_bytes(1) + 
                                    int(0).to_bytes(1) + 
                                    int(key_on).to_bytes(1)))
        else:
            voices = patch.getVoices()
            detune = patch.getDetune()
            strides = calculate_unison_strides(freq, detune, voices)
            for index, s in zip(hw_indices, strides):
                self.send_serial(bytes((0xDEADBEEF).to_bytes(4)))
                self.send_serial(bytes(s.to_bytes(4) + 
                                    index.to_bytes(1) + 
                                    waves[0].to_bytes(4) + 
                                    envelope.to_bytes(1) + 
                                    int(0).to_bytes(1) + 
                                    int(key_on).to_bytes(1)))
