@echo off
set PYTHONPATH=%CD%
echo --- Starting ByteTrack Video Demo ---
echo Press 'q' to exit.

python tools/demo_track.py video --path videos/palace.mp4 -f exps/example/mot/yolox_tiny_cpu.py -c pretrained/bytetrack_tiny_mot17.pth.tar --device cpu --save_result --firebase_url https://iot-seat-occupancy-default-rtdb.firebaseio.com/ --track_thresh 0.5 --conf 0.25 --min_box_area 100

pause
