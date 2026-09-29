import cv2
import mediapipe as mp
import json
import os

# 1. Configuration
VIDEO_PATH = 'Bicep_Curl_Demo_Video.mp4'  
OUTPUT_JSON = 'test/traces/bicep_curl_telemetry.json'

def extract_telemetry():
    if not os.path.exists(VIDEO_PATH):
        print(f"❌ Error: Cannot find video at {VIDEO_PATH}")
        return

    print("⏳ Initializing MediaPipe...")
    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose(
        static_image_mode=False, 
        model_complexity=1, 
        min_detection_confidence=0.5
    )

    cap = cv2.VideoCapture(VIDEO_PATH)
    fps = cap.get(cv2.CAP_PROP_FPS)
    frame_ms_increment = (1000.0 / fps) if fps > 0 else 33.3

    telemetry = []
    current_ms = 0.0
    frame_count = 0

    print("🏃 Extracting upper-body and torso frames for Bicep Curl...")
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        
        # Convert BGR to RGB for MediaPipe processing
        image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = pose.process(image)

        if results.pose_landmarks:
            landmarks = results.pose_landmarks.landmark
            
            # MediaPipe Indices:
            # 11=LeftShoulder, 12=RightShoulder
            # 13=LeftElbow, 14=RightElbow
            # 15=LeftWrist, 16=RightWrist
            # 23=LeftHip, 24=RightHip
            frame_data = {
                "frame_ms": int(current_ms),
                "landmarks": {
                    "right_shoulder": {"x": landmarks[12].x, "y": landmarks[12].y, "c": landmarks[12].visibility},
                    "right_elbow": {"x": landmarks[14].x, "y": landmarks[14].y, "c": landmarks[14].visibility},
                    "right_wrist": {"x": landmarks[16].x, "y": landmarks[16].y, "c": landmarks[16].visibility},
                    "right_hip": {"x": landmarks[24].x, "y": landmarks[24].y, "c": landmarks[24].visibility},
                    
                    "left_shoulder": {"x": landmarks[11].x, "y": landmarks[11].y, "c": landmarks[11].visibility},
                    "left_elbow": {"x": landmarks[13].x, "y": landmarks[13].y, "c": landmarks[13].visibility},
                    "left_wrist": {"x": landmarks[15].x, "y": landmarks[15].y, "c": landmarks[15].visibility},
                    "left_hip": {"x": landmarks[23].x, "y": landmarks[23].y, "c": landmarks[23].visibility},
                }
            }
            telemetry.append(frame_data)
        
        current_ms += frame_ms_increment

    cap.release()

    # Ensure output directory exists
    os.makedirs(os.path.dirname(OUTPUT_JSON), exist_ok=True)

    # Save to JSON
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(telemetry, f, indent=2)

    print(f"✅ Success! Extracted {len(telemetry)} frames of bicep curl data.")
    print(f"📁 Saved to: {OUTPUT_JSON}")

if __name__ == "__main__":
    extract_telemetry()