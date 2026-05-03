import cv2
import numpy as np
import lap
from scipy.spatial.distance import cdist

from yolox.motdt_tracker import kalman_filter

def bbox_overlaps(bboxes1, bboxes2):
    """
    Pure Python/Numpy implementation of bbox IOU.
    Args:
        bboxes1: shape (N, 4) <x1, y1, x2, y2>
        bboxes2: shape (M, 4) <x1, y1, x2, y2>
    Returns:
        ious: shape (N, M)
    """
    bboxes1 = np.ascontiguousarray(bboxes1, dtype=np.float32)
    bboxes2 = np.ascontiguousarray(bboxes2, dtype=np.float32)
    
    if bboxes1.shape[0] == 0 or bboxes2.shape[0] == 0:
        return np.zeros((bboxes1.shape[0], bboxes2.shape[0]), dtype=np.float32)

    x11, y11, x12, y12 = np.split(bboxes1, 4, axis=1)
    x21, y21, x22, y22 = np.split(bboxes2, 4, axis=1)

    # Vectorized calculation
    xA = np.maximum(x11, x21.T)
    yA = np.maximum(y11, y21.T)
    xB = np.minimum(x12, x22.T)
    yB = np.minimum(y12, y22.T)

    interArea = np.maximum(0, xB - xA) * np.maximum(0, yB - yA)
    boxAArea = (x12 - x11) * (y12 - y11)
    boxBArea = (x22 - x21) * (y22 - y21)
    
    # Avoid division by zero
    unionArea = (boxAArea + boxBArea.T - interArea)
    iou = np.divide(interArea, unionArea, out=np.zeros_like(interArea), where=unionArea!=0)

    return iou


def _indices_to_matches(cost_matrix, indices, thresh):
    matched_cost = cost_matrix[tuple(zip(*indices))]
    matched_mask = (matched_cost <= thresh)

    matches = indices[matched_mask]
    unmatched_a = tuple(set(range(cost_matrix.shape[0])) - set(matches[:, 0]))
    unmatched_b = tuple(set(range(cost_matrix.shape[1])) - set(matches[:, 1]))

    return matches, unmatched_a, unmatched_b


def linear_assignment(cost_matrix, thresh):
    if cost_matrix.size == 0:
        return np.empty((0, 2), dtype=int), tuple(range(cost_matrix.shape[0])), tuple(range(cost_matrix.shape[1]))
    matches, unmatched_a, unmatched_b = [], [], []
    cost, x, y = lap.lapjv(cost_matrix, extend_cost=True, cost_limit=thresh)
    for ix, mx in enumerate(x):
        if mx >= 0:
            matches.append([ix, mx])
    unmatched_a = np.where(x < 0)[0]
    unmatched_b = np.where(y < 0)[0]
    matches = np.asarray(matches)
    return matches, unmatched_a, unmatched_b


def ious(atlbrs, btlbrs):
    """
    Compute cost based on IoU
    :type atlbrs: list[tlbr] | np.ndarray
    :type atlbrs: list[tlbr] | np.ndarray
    :rtype ious np.ndarray
    """
    ious = np.zeros((len(atlbrs), len(btlbrs)), dtype=np.float32)
    if ious.size == 0:
        return ious

    ious = bbox_overlaps(
        np.ascontiguousarray(atlbrs, dtype=np.float32),
        np.ascontiguousarray(btlbrs, dtype=np.float32)
    )

    return ious


def iou_distance(atracks, btracks):
    """
    Compute cost based on IoU
    :type atracks: list[STrack]
    :type btracks: list[STrack]
    :rtype cost_matrix np.ndarray
    """
    atlbrs = [track.tlbr for track in atracks]
    btlbrs = [track.tlbr for track in btracks]
    _ious = ious(atlbrs, btlbrs)
    cost_matrix = 1 - _ious

    return cost_matrix


def nearest_reid_distance(tracks, detections, metric='cosine'):
    """
    Compute cost based on ReID features
    :type tracks: list[STrack]
    :type detections: list[BaseTrack]
    :rtype cost_matrix np.ndarray
    """
    cost_matrix = np.zeros((len(tracks), len(detections)), dtype=np.float32)
    if cost_matrix.size == 0:
        return cost_matrix

    det_features = np.asarray([track.curr_feature for track in detections], dtype=np.float32)
    for i, track in enumerate(tracks):
        cost_matrix[i, :] = np.maximum(0.0, cdist(track.features, det_features, metric).min(axis=0))

    return cost_matrix


def mean_reid_distance(tracks, detections, metric='cosine'):
    """
    Compute cost based on ReID features
    :type tracks: list[STrack]
    :type detections: list[BaseTrack]
    :type metric: str
    :rtype cost_matrix np.ndarray
    """
    cost_matrix = np.empty((len(tracks), len(detections)), dtype=np.float32)
    if cost_matrix.size == 0:
        return cost_matrix

    track_features = np.asarray([track.curr_feature for track in tracks], dtype=np.float32)
    det_features = np.asarray([track.curr_feature for track in detections], dtype=np.float32)
    cost_matrix = cdist(track_features, det_features, metric)

    return cost_matrix


def gate_cost_matrix(kf, cost_matrix, tracks, detections, only_position=False):
    if cost_matrix.size == 0:
        return cost_matrix
    gating_dim = 2 if only_position else 4
    gating_threshold = kalman_filter.chi2inv95[gating_dim]
    measurements = np.asarray([det.to_xyah() for det in detections])
    for row, track in enumerate(tracks):
        gating_distance = kf.gating_distance(
            track.mean, track.covariance, measurements, only_position)
        cost_matrix[row, gating_distance > gating_threshold] = np.inf
    return cost_matrix