from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import cv2
import numpy as np
import uvicorn
import os

app = FastAPI(title="Prodesx Face Vector API (Using AI SFace Model)")

# Add CORS middleware to allow requests from the Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Path to AI models (YuNet and SFace)
MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")
YUNET_PATH = os.path.join(MODELS_DIR, "face_detection_yunet.onnx")
SFACE_PATH = os.path.join(MODELS_DIR, "face_recognition_sface.onnx")

# Initialize AI Detector and Recognizer
# (YuNet is extremely fast and accurate; SFace handles lighting/shading)
detector = cv2.FaceDetectorYN.create(YUNET_PATH, "", (0, 0))
recognizer = cv2.FaceRecognizerSF.create(SFACE_PATH, "")

def get_sface_embedding(img_color):
    """
    AI-based SFace implementation to generate a 128-d face vector.
    Much more robust to lighting/shading than LBP.
    """
    h, w, _ = img_color.shape
    detector.setInputSize((w, h))
    
    # 1. Detect face (YuNet)
    _, faces_raw = detector.detect(img_color)
    if faces_raw is None:
        return None

    faces = np.array(faces_raw)
    if faces.shape[0] == 0:
        return None

    # Check detection confidence (Index 14 in the detection array)
    detection_confidence = faces[0][14]
    if detection_confidence < 0.85:  # Lowered from 0.9 to 0.85 for better detection
        print(f"DEBUG: Face detected but low confidence ({detection_confidence:.2f}). Rejecting.")
        return None

    # 2. Align and extract features (SFace)
    face_aligned = recognizer.alignCrop(img_color, faces[0])
    feature = recognizer.feature(face_aligned)
    
    #3.Return 128-d vector
    return feature[0].tolist()

@app.get("/")
async def root():
    return {"message": "Prodesx Face Vector API is running (Using AI SFace Model)"}

@app.post("/get-embedding")
async def get_embedding(file: UploadFile = File(...)):
    """Generates a 128-d stable vector for a face using SFace AI model."""
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        return {"status": "error", "message": "Image not found, Failed to decode image"}

    vector = get_sface_embedding(img)
    if vector is None:
        return {"status": "error", "message": "No face detected"}
    
    print(f"DEBUG: Vector generated successfully. Size: {len(vector)}")
    return {
        "status": "success",
        "embedding": vector
    }

@app.post("/detect-pose")
async def detect_pose(file: UploadFile = File(...)):
    """
    Heuristic pose detection (straight, left, right, down) 
    using YuNet 5-point landmarks.
    """
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if img is None:
        return {"status": "error", "message": "Failed to decode image"}

    h, w, _ = img.shape
    detector.setInputSize((w, h))
    _, faces_raw = detector.detect(img)

    if faces_raw is not None:
        faces = np.array(faces_raw)
        if faces.shape[0] > 0:
            face = faces[0]
            conf = face[14]
            if conf < 0.85: # Lowered from 0.95 to 0.85
                print(f"DEBUG POSE: Face detected but low confidence ({conf:.2f}).")
                return {"status": "error", "message": "Face detected with low confidence"}
            
            # Landmarks: 4-13 (5 points: x,y each)
            # 0: Left Eye, 1: Right Eye, 2: Nose Tip, 3: Left Mouth, 4: Right Mouth
            landmarks = face[4:14].reshape(5, 2)
            
            l_eye = landmarks[0]
            r_eye = landmarks[1]
            nose = landmarks[2]
            
            # Landmarks: 0: L Eye, 1: R Eye, 2: Nose, 3: L Mouth, 4: R Mouth
            l_eye, r_eye, nose, l_mouth, r_mouth = landmarks
            
            # 1. Yaw (Left/Right) - Horizontal ratio
            d_l = abs(nose[0] - l_eye[0])
            d_r = abs(nose[0] - r_eye[0])
            yaw_ratio = d_l / (d_l + d_r) if (d_l + d_r) > 0 else 0.5
            
            # 2. Pitch (Down) - Vertical ratio
            # Use distance from eyes to nose vs eyes to mouth
            eye_y = (l_eye[1] + r_eye[1]) / 2
            mouth_y = (l_mouth[1] + r_mouth[1]) / 2
            
            dist_e_n = nose[1] - eye_y
            dist_n_m = mouth_y - nose[1]
            dist_total_v = dist_e_n + dist_n_m
            
            pitch_ratio = dist_e_n / dist_total_v if dist_total_v > 0 else 0.5
            
            # Determine Pose
            pose = "straight"
            if yaw_ratio < 0.33:
                pose = "right"
            elif yaw_ratio > 0.67:
                pose = "left"
            elif pitch_ratio > 0.58: # Adjusted to avoid collision with 'straight'
                pose = "down"
            
            print(f"DEBUG POSE: yaw={yaw_ratio:.3f}, pitch={pitch_ratio:.3f} -> POSE: {pose}")
                
            return {
                "status": "success",
                "pose": pose,
                "confidence": float(conf),
                "yaw_ratio": float(yaw_ratio),
                "pitch_ratio": float(pitch_ratio)
            }

    return {"status": "error", "message": "No face detected"}

    return {"status": "error", "message": "No face detected"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
