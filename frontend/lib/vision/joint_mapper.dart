class JointMapper {
  // Maps MediaPipe index directly to your string/enum keys
  static String poseKey(int mediapipeIndex) {
    const Map<int, String> indexToKey = {
      0: 'nose',
      11: 'leftShoulder',
      12: 'rightShoulder',
      13: 'leftElbow',
      14: 'rightElbow',
      15: 'leftWrist',
      16: 'rightWrist',
      23: 'leftHip',
      24: 'rightHip',
      25: 'leftKnee',
      26: 'rightKnee',
      27: 'leftAnkle',
      28: 'rightAnkle',
      29: 'leftHeel',       // NEW
      30: 'rightHeel',      // NEW
      31: 'leftFootIndex',  // NEW
      32: 'rightFootIndex', // NEW
    };
    
    return indexToKey[mediapipeIndex] ?? 'unknown_$mediapipeIndex';
  }
}