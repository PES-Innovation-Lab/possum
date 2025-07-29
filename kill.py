import serial
import struct
import sys
import time
import threading

def serial_logger(ser, stop_event):
    while not stop_event.is_set():
        if ser.in_waiting:
            try:
                data = ser.read(ser.in_waiting)
                print(data.decode(errors="replace"), end="")
            except Exception:
                pass
        time.sleep(0.01)

def send_killtask_uart(port, baudrate, identifier):
    ser = serial.Serial(port, baudrate, timeout=1)
    time.sleep(2)

    stop_event = threading.Event()
    logger_thread = threading.Thread(target=serial_logger, args=(ser, stop_event))
    logger_thread.start()

    print("[INFO] Logging serial output for 2 seconds...")
    time.sleep(2)

    print("[INFO] Sending KILLTASK keyword...")
    ser.write(b'KILLTASK')
    time.sleep(0.05)

    # Send identifier as 8 bytes (padded or truncated)
    identifier_bytes = identifier.encode('utf-8')[:8].ljust(8, b'\x00')
    print(f"[INFO] Sending identifier: {identifier_bytes}")
    ser.write(identifier_bytes)
    time.sleep(0.05)

    print("[INFO] Logging serial output for 2 more seconds...")
    time.sleep(2)

    stop_event.set()
    logger_thread.join()
    ser.close()

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python kill.py <COM_PORT> <BAUDRATE> <IDENTIFIER>")
        sys.exit(1)
    send_killtask_uart(sys.argv[1], int(sys.argv[2]), sys.argv[3])
