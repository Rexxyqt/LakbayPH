import subprocess
import sys
import time
import os

def main():
    print("Starting FastAPI Backend Server...")
    # Start the server
    server_process = subprocess.Popen([sys.executable, "server.py"])
    
    # Give the server a few seconds to initialize
    time.sleep(3)
    
    print("Starting AI Passenger Tracking...")
    # Set up paths for ajav
    ajav_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "ajav"))
    
    env = os.environ.copy()
    env["PYTHONPATH"] = ajav_dir
    print("\n" + "="*50)
    print(" " * 10 + "LAKBAY PH TRACKING SYSTEM")
    print("="*50)
    print("Please choose your video source:")
    print("  1. Demo Video (palace.mp4)")
    print("  2. Live Webcam")
    choice = input("\nEnter choice (1 or 2): ").strip()

    demo_script = os.path.join("tools", "demo_track.py")
    
    if choice == '2':
        print("Starting Live Webcam...")
        tracking_args = [
            sys.executable, demo_script, "webcam",
            "--camid", "0",
            "-f", os.path.join("exps", "example", "mot", "yolox_tiny_cpu.py"),
            "-c", os.path.join("pretrained", "bytetrack_tiny_mot17.pth.tar"),
            "--device", "cpu",
            "--save_result",
            "--track_thresh", "0.5",
            "--conf", "0.25",
            "--min_box_area", "100"
        ]
    else:
        print("Starting Demo Video...")
        tracking_args = [
            sys.executable, demo_script, "video",
            "--path", os.path.join("videos", "palace.mp4"),
            "-f", os.path.join("exps", "example", "mot", "yolox_tiny_cpu.py"),
            "-c", os.path.join("pretrained", "bytetrack_tiny_mot17.pth.tar"),
            "--device", "cpu",
            "--save_result",
            "--track_thresh", "0.5",
            "--conf", "0.25",
            "--min_box_area", "100"
        ]

    tracking_process = subprocess.Popen(tracking_args, env=env, cwd=ajav_dir)

    try:
        # Wait for either process to finish/crash
        while server_process.poll() is None and tracking_process.poll() is None:
            time.sleep(1)
            
        print("\nOne of the processes exited.")
    except KeyboardInterrupt:
        print("\nCtrl+C detected. Shutting down both processes safely...")
    finally:
        # Terminate both processes
        if server_process.poll() is None:
            server_process.terminate()
        if tracking_process.poll() is None:
            tracking_process.terminate()
        
        server_process.wait()
        tracking_process.wait()
        print("Shutdown complete.")

if __name__ == "__main__":
    main()
