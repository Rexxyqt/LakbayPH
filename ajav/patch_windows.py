import os
import re
import subprocess
import sys

def patch_file(path, search, replace):
    if not os.path.exists(path):
        print(f"Skipping: {path} (Not found)")
        return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if search in content:
        new_content = content.replace(search, replace)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Patched: {path}")
    else:
        print(f"Already patched or search string not found in: {path}")

print("--- Starting Windows Patch & Setup ---")

# 1. Fix np.float deprecation
files_to_fix_np = [
    'yolox/tracker/byte_tracker.py',
    'yolox/tracker/matching.py',
    'yolox/utils/boxes.py',
    'yolox/deepsort_tracker/detection.py',
    'yolox/motdt_tracker/matching.py',
    'yolox/motdt_tracker/motdt_tracker.py',
    'yolox/motdt_tracker/reid_model.py'
]

for f in files_to_fix_np:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    new_content = re.sub(r'np\.float\b', 'float', content)
    if new_content != content:
        with open(f, 'w', encoding='utf-8') as file:
            file.write(new_content)
        print(f"Fixed np.float in: {f}")

# 2. Replace cython_bbox with Pure Python IOU
matching_path = 'yolox/tracker/matching.py'
iou_code = """
import numpy as np

def bbox_overlaps(bboxes1, bboxes2):
    bboxes1 = bboxes1.astype(float)
    bboxes2 = bboxes2.astype(float)
    if bboxes1.ndim == 1: bboxes1 = bboxes1[None, :]
    if bboxes2.ndim == 1: bboxes2 = bboxes2[None, :]
    
    rows = bboxes1.shape[0]
    cols = bboxes2.shape[0]
    ious = np.zeros((rows, cols))
    if rows * cols == 0: return ious
    
    exchange = False
    if bboxes1.shape[0] > bboxes2.shape[0]:
        bboxes1, bboxes2 = bboxes2, bboxes1
        ious = np.zeros((cols, rows))
        exchange = True

    area1 = (bboxes1[:, 2] - bboxes1[:, 0]) * (bboxes1[:, 3] - bboxes1[:, 1])
    area2 = (bboxes2[:, 2] - bboxes2[:, 0]) * (bboxes2[:, 3] - bboxes2[:, 1])

    for i in range(bboxes1.shape[0]):
        x_start = np.maximum(bboxes1[i, 0], bboxes2[:, 0])
        y_start = np.maximum(bboxes1[i, 1], bboxes2[:, 1])
        x_end = np.minimum(bboxes1[i, 2], bboxes2[:, 2])
        y_end = np.minimum(bboxes1[i, 3], bboxes2[:, 3])
        
        w = np.maximum(0.0, x_end - x_start)
        h = np.maximum(0.0, y_end - y_start)
        inter = w * h
        ious[i, :] = inter / (area1[i] + area2 - inter)
    
    return ious.T if exchange else ious
"""
patch_file(matching_path, 'from cython_bbox import bbox_overlaps', iou_code)

# 3. Create missing directories
dirs = ['pretrained', 'exps/example/mot']
for d in dirs:
    if not os.path.exists(d):
        os.makedirs(d)
        print(f"Created directory: {d}")

# 4. Download Models using gdown
print("\nDownloading models (this may take a while)...")
try:
    import gdown
    models = {
        'pretrained/bytetrack_s_mot17.pth.tar': '1uSmhXzyV1Zvb4TJJCzpsZOIcw7CCJLxj',
        'pretrained/bytetrack_tiny_mot17.pth.tar': '1LFAl14sql2Q5Y9aNFsX_OqsnIzUD_1ju'
    }
    for path, g_id in models.items():
        if not os.path.exists(path):
            print(f"Downloading {path}...")
            gdown.download(id=g_id, output=path, quiet=False)
        else:
            print(f"Model already exists: {path}")
except ImportError:
    print("Error: gdown not installed. Please run 'pip install gdown' first.")

print("\n--- Setup Complete! ---")
