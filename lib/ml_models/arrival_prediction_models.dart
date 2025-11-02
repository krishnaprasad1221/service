import 'dart:math';

class _DistanceIndex {
  final double distance;
  final int index;
  
  _DistanceIndex(this.distance, this.index);
}

class ArrivalPredictionModels {
  // Service type weights (how much each service type affects allocation time)
  static const Map<int, double> _serviceTypeWeights = {
    1: 1.2, // Emergency service - higher priority
    2: 1.0, // Standard service
    3: 0.8, // Scheduled maintenance
    4: 1.1, // Premium service
    5: 0.9, // Basic service
  };
  
  // Training data
  static List<List<double>> _trainingData = [
    [9, 1, 2, 5.0, 3, 1, 20, 0, 0, 45, 0],  // Monday morning, service type 2
    [14, 2, 1, 10.0, 4, 0.8, 35, 0, 1, 60, 30], // Tuesday afternoon, service type 1
    [18, 5, 3, 15.0, 5, 0.6, 50, 1, 2, 90, 45], // Friday evening, service type 3
    [11, 3, 4, 2.0, 2, 0.9, 10, 0, 0, 30, 15], // Wednesday morning, service type 4
    [16, 4, 2, 8.0, 3, 0.7, 30, 0, 1, 60, 30], // Thursday afternoon, service type 2
    [10, 6, 1, 12.0, 4, 0.5, 40, 1, 0, 75, 20], // Saturday morning, service type 1
    [13, 7, 5, 7.0, 3, 0.4, 25, 1, 1, 45, 25], // Sunday afternoon, service type 5
    [17, 3, 3, 20.0, 5, 0.8, 60, 0, 2, 120, 60], // Wednesday evening, service type 3
    [9, 5, 2, 3.0, 2, 0.7, 12, 0, 0, 40, 0],  // Friday morning, service type 2
    [15, 4, 4, 9.0, 4, 0.6, 32, 0, 1, 50, 30],  // Thursday afternoon, service type 4
  ];
  
  // Time slot weights (morning, afternoon, evening, night)
  static const List<double> _timeSlotWeights = [1.1, 1.0, 0.9, 1.3];
  
  // Helper methods for feature processing
  String _getTimeOfDay(double hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }
  
  String _getTrafficLevel(double traffic) {
    if (traffic < 2) return 'light';
    if (traffic < 3) return 'moderate';
    if (traffic < 4) return 'heavy';
    return 'severe';
  }
  
  String _getDistanceCategory(double distance) {
    if (distance < 5) return 'short';
    if (distance < 15) return 'medium';
    return 'long';
  }
  
  List<double> _normalizeFeatures(List<double> features) {
    // Simple normalization to 0-1 range for each feature
    final normalized = List<double>.from(features);
    
    // Hour (0-23) -> 0-1
    normalized[0] = features[0] / 23.0;
    
    // Day of week (1-7) -> 0-1
    normalized[1] = (features[1] - 1) / 6.0;

    // Service type (1-5) -> 0-1
    normalized[2] = (features[2] - 1) / 4.0;

    // Distance (0-50 km) -> 0-1
    normalized[3] = features[3] / 50.0;

    // Traffic (1-5) -> 0-1
    normalized[4] = features.length > 4 ? (features[4] - 1) / 4.0 : 0.5;

    return normalized;
  }
  // Format: [hour_of_day, day_of_week, service_type(1-5), distance_km, 
  //          traffic_condition(1-5), provider_availability(0-1), 
  //          historical_avg_arrival_min, is_weekend(0/1), 
  //          time_slot(0=morning,1=afternoon,2=evening,3=night),
  //          booking_duration_min, time_since_last_booking_min]
  List<List<double>> getTrainingData() {
    return _trainingData;
  }

  // Add a new booking to the training data to improve future predictions
  void addBookingToTrainingData(DateTime bookingTime, int serviceType, double distance, 
                              int traffic, double duration, double timeSinceLastBooking) {
    final hour = bookingTime.hour + (bookingTime.minute / 60);
    final day = bookingTime.weekday.toDouble();
    final isWeekend = (day >= 6) ? 1.0 : 0.0;
    
    // Determine time slot (0=morning,1=afternoon,2=evening,3=night)
    int timeSlot;
    if (hour >= 5 && hour < 12) {
      timeSlot = 0; // Morning
    } else if (hour >= 12 && hour < 17) {
      timeSlot = 1; // Afternoon
    } else if (hour >= 17 && hour < 21) {
      timeSlot = 2; // Evening
    } else {
      timeSlot = 3; // Night
    }
    
    // Add to training data
    _trainingData.add([
      hour,
      day,
      serviceType.toDouble(),
      distance,
      traffic.toDouble(),
      1.0, // provider availability (1 = available)
      duration, // actual service duration
      isWeekend,
      timeSlot.toDouble(),
      duration,
      timeSinceLastBooking
    ]);
    
    // Keep training data size manageable (last 1000 entries)
    if (_trainingData.length > 1000) {
      _trainingData.removeAt(0);
    }
  }
  
  // Get optimal booking time based on current schedule
  DateTime getOptimalBookingTime(DateTime preferredTime, int serviceType, 
                               {int lookaheadHours = 24}) {
    final now = DateTime.now();
    DateTime bestTime = preferredTime;
    double bestScore = double.negativeInfinity;
    
    // Check time slots in the next lookaheadHours
    for (int minutes = 0; minutes < lookaheadHours * 60; minutes += 30) {
      final checkTime = preferredTime.add(Duration(minutes: minutes));
      if (checkTime.isBefore(now)) continue;
      
      // Calculate time since last booking
      double timeSinceLast = 0;
      if (_trainingData.isNotEmpty) {
        final lastBooking = _trainingData.last;
        final lastTime = DateTime(
          now.year, now.month, now.day, 
          lastBooking[0].toInt(), 
          ((lastBooking[0] - lastBooking[0].toInt()) * 60).toInt()
        );
        timeSinceLast = checkTime.difference(lastTime).inMinutes.toDouble();
      }
      
      // Predict wait time for this slot
      final features = [
        checkTime.hour + (checkTime.minute / 60),
        checkTime.weekday.toDouble(),
        serviceType.toDouble(),
        5.0, // average distance
        3.0, // average traffic
        timeSinceLast
      ];
      
      final waitTime = predictWithKNN(features);
      
      // Calculate score (lower wait time is better, but also consider time of day)
      double score = -waitTime; // Lower wait time is better
      
      // Prefer times closer to preferred time
      final timeDiff = (checkTime.difference(preferredTime).inMinutes / 60).abs();
      score -= timeDiff * 0.5; // Penalize times far from preferred time
      
      // Prefer business hours
      if (checkTime.hour >= 9 && checkTime.hour < 17) {
        score += 10; // Bonus for business hours
      }
      
      if (score > bestScore) {
        bestScore = score;
        bestTime = checkTime;
      }
    }
    
    return bestTime;
  }
  
  // K-Nearest Neighbors (KNN) for arrival time prediction
  double predictWithKNN(List<double> inputFeatures, {int k = 3}) {
    if (_trainingData.isEmpty) return 30.0; // Default fallback
    
    // Extract and validate features
    if (inputFeatures.length < 5) {
      throw Exception('Invalid number of features. Expected at least 5, got ${inputFeatures.length}');
    }
    
    final serviceType = inputFeatures[2].toInt();
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Calculate distances to all training points
    final distances = <_DistanceIndex>[];
    
    for (int i = 0; i < _trainingData.length; i++) {
      final trainingPoint = _trainingData[i];
      if (trainingPoint.length < 11) continue; // Skip invalid data
      
      double distance = 0.0;
      // Compare each feature (hour, day, service type, distance, traffic)
      for (int j = 0; j < 5 && j < inputFeatures.length && j < trainingPoint.length; j++) {
        // Apply service type weight to distance calculation
        final weight = j == 2 ? serviceWeight : 1.0;
        distance += weight * pow(inputFeatures[j] - trainingPoint[j], 2);
      }
      
      distances.add(_DistanceIndex(sqrt(distance), i));
    }
    
    // Sort by distance and get k nearest neighbors
    distances.sort((a, b) => a.distance.compareTo(b.distance));
    
    // Take the average of the k nearest neighbors' arrival times
    double totalArrivalTime = 0.0;
    int count = 0;
    
    for (int i = 0; i < k && i < distances.length; i++) {
      final idx = distances[i].index;
      // The arrival time is at index 9 in the training data
      if (idx < _trainingData.length && _trainingData[idx].length > 9) {
        totalArrivalTime += _trainingData[idx][9];
        count++;
      }
    }
    
    return count > 0 ? totalArrivalTime / count : 30.0; // Default to 30 minutes if no neighbors found
  }
  
  // Support Vector Machine (SVM) for arrival time prediction
  double predictWithSVM(List<double> inputFeatures) {
    if (_trainingData.isEmpty) return 30.0; // Default fallback
    
    // Simple linear SVM implementation
    // In a real app, you'd want to use a proper ML library for this
    
    // Extract and validate features
    if (inputFeatures.length < 5) {
      throw Exception('Invalid number of features. Expected at least 5, got ${inputFeatures.length}');
    }
    
    final serviceType = inputFeatures[2].toInt();
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Simple linear combination of features with weights
    double prediction = 0.0;
    
    // Weights for each feature (these would normally be learned during training)
    final weights = [0.5, 0.2, 0.8, 0.7, 0.6];
    
    for (int i = 0; i < 5 && i < inputFeatures.length; i++) {
      // Apply service type weight to service type feature
      final featureWeight = i == 2 ? serviceWeight : 1.0;
      prediction += weights[i] * inputFeatures[i] * featureWeight;
    }
    
    // Add bias term
    prediction += 15.0;
    
    // Ensure prediction is within reasonable bounds
    return prediction.clamp(10.0, 180.0);
  }
  
  // Decision Tree for arrival time prediction
  double predictWithDecisionTree(List<double> inputFeatures) {
    if (inputFeatures.length < 5) {
      throw Exception('Invalid number of features. Expected at least 5, got ${inputFeatures.length}');
    }
    
    // Extract features
    final hour = inputFeatures[0];
    final day = inputFeatures[1];
    final serviceType = inputFeatures[2].toInt();
    final distance = inputFeatures[3];
    final traffic = inputFeatures[4];
    
    // Get service weight
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Simple decision tree rules
    double baseEta = 30.0; // Base ETA in minutes
    
    // Time of day factor (morning/evening rush hours)
    if ((hour >= 7 && hour < 10) || (hour >= 16 && hour < 19)) {
      baseEta *= 1.5; // Rush hour
    } else if (hour >= 22 || hour < 6) {
      baseEta *= 0.8; // Late night/early morning
    }
    
    // Day of week factor (weekends are different)
    if (day >= 6) { // Weekend
      baseEta *= 1.2;
    }
    
    // Service type factor
    baseEta *= serviceWeight;
    
    // Distance factor (assume 5km = 30 minutes as baseline)
    baseEta *= (distance / 5.0);
    
    // Traffic factor
    baseEta *= (1 + (traffic - 1) * 0.2); // 1-5 scale, 1=no traffic, 5=heavy traffic
    
    return baseEta.clamp(10.0, 240.0); // Clamp between 10 minutes and 4 hours
  }
  
  // Neural Network for arrival time prediction
  double predictWithNeuralNetwork(List<double> inputFeatures) {
    if (_trainingData.isEmpty) return 30.0; // Default fallback
    
    // Simple feedforward neural network with one hidden layer
    // In a real app, you'd want to use a proper ML library for this
    
    // Input layer (5 features)
    if (inputFeatures.length < 5) {
      throw Exception('Invalid number of features. Expected at least 5, got ${inputFeatures.length}');
    }
    
    // Normalize input features
    final normalizedFeatures = _normalizeFeatures(inputFeatures);
    
    // Hidden layer weights (5x4)
    final hiddenWeights = [
      [0.2, 0.3, -0.1, 0.4],
      [0.1, 0.4, 0.2, -0.3],
      [0.3, -0.2, 0.4, 0.1],
      [-0.1, 0.3, 0.2, 0.4],
      [0.2, 0.1, -0.3, 0.2],
    ];
    
    // Hidden layer biases (4)
    final hiddenBiases = [0.1, 0.2, -0.1, 0.1];
    
    // Output layer weights (4x1)
    final outputWeights = [0.4, 0.3, 0.2, 0.1];
    
    // Calculate hidden layer activations
    final hiddenLayer = List.filled(4, 0.0);
    for (int i = 0; i < 4; i++) {
      double sum = hiddenBiases[i];
      for (int j = 0; j < 5; j++) {
        sum += normalizedFeatures[j] * hiddenWeights[j][i];
      }
      // ReLU activation
      hiddenLayer[i] = sum > 0 ? sum : 0;
    }
    
    // Calculate output
    double output = 0.0;
    for (int i = 0; i < 4; i++) {
      output += hiddenLayer[i] * outputWeights[i];
    }
    
  
    final prediction = 10.0 + output * 170.0;
    
    return prediction.clamp(10.0, 180.0);
  }
  
  // Naive Bayes implementation for arrival time prediction
  double predictWithNaiveBayes(List<double> inputFeatures) {
    if (_trainingData.isEmpty) return 30.0; // Default fallback
    
    if (inputFeatures.length < 5) {
      throw Exception('Invalid number of features. Expected at least 5, got ${inputFeatures.length}');
    }
    
   
    final hour = inputFeatures[0];
    final day = inputFeatures[1];
    final serviceType = inputFeatures[2].toInt();
    final distance = inputFeatures[3];
    final traffic = inputFeatures[4];
    
   
    final distanceCategory = distance < 5 ? 'short' : (distance < 15 ? 'medium' : 'long');
    

    final timeOfDay = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : (hour < 21 ? 'evening' : 'night'));
    
   
    final trafficLevel = traffic < 2.5 ? 'light' : (traffic < 3.5 ? 'moderate' : 'heavy');
    
 
    final classCounts = <int, int>{};
    final featureCounts = <int, Map<String, Map<String, int>>>{};
    
    // Initialize counts
    for (final point in _trainingData) {
      if (point.length < 11) continue;
      
      // Discretize the arrival time to 15-minute intervals
      final arrivalTime = point[9]; // Arrival time is at index 9
      final interval = (arrivalTime / 15).floor() * 15;
      
      // Update class counts
      classCounts[interval] = (classCounts[interval] ?? 0) + 1;
      
      // Initialize feature counts for this class if needed
      if (!featureCounts.containsKey(interval)) {
        featureCounts[interval] = {
          'timeOfDay': {},
          'dayType': {},
          'serviceType': {},
          'distance': {},
          'traffic': {},
        };
      }
      
      // Get feature values for this training point
      final ptHour = point[0];
      final ptDay = point[1];
      final ptServiceType = point[2].toInt();
      final ptDistance = point[3];
      final ptTraffic = point[4];
      
      // Discretize features for this point
      final ptTimeOfDay = ptHour < 12 ? 'morning' : (ptHour < 17 ? 'afternoon' : (ptHour < 21 ? 'evening' : 'night'));
      final ptDayType = ptDay >= 6 ? 'weekend' : 'weekday';
      final ptDistanceCat = ptDistance < 5 ? 'short' : (ptDistance < 15 ? 'medium' : 'long');
      final ptTrafficLevel = ptTraffic < 2.5 ? 'light' : (ptTraffic < 3.5 ? 'moderate' : 'heavy');
      
      // Update feature counts for this class
      final features = featureCounts[interval]!;
      features['timeOfDay']![ptTimeOfDay] = (features['timeOfDay']![ptTimeOfDay] ?? 0) + 1;
      features['dayType']![ptDayType] = (features['dayType']![ptDayType] ?? 0) + 1;
      features['serviceType']![ptServiceType.toString()] = (features['serviceType']![ptServiceType.toString()] ?? 0) + 1;
      features['distance']![ptDistanceCat] = (features['distance']![ptDistanceCat] ?? 0) + 1;
      features['traffic']![ptTrafficLevel] = (features['traffic']![ptTrafficLevel] ?? 0) + 1;
    }
    
    // Calculate prior probabilities
    final totalPoints = _trainingData.length;
    final classProbs = <int, double>{};
    
    // Calculate likelihood for each class
    double maxProb = -1;
    int bestClass = 30; // Default to 30 minutes
    
    for (final interval in classCounts.keys) {
      final classCount = classCounts[interval]!;
      final prior = classCount / totalPoints;
      
      // Get feature counts for this class
      final features = featureCounts[interval]!;
      
      // Calculate likelihood for each feature (with Laplace smoothing)
      double likelihood = 1.0;
      final timeOfDayCount = features['timeOfDay']?[timeOfDay] ?? 0;
      final dayTypeCount = features['dayType']?[day >= 6 ? 'weekend' : 'weekday'] ?? 0;
      final serviceTypeCount = features['serviceType']?[serviceType.toString()] ?? 0;
      final distanceCount = features['distance']?[distanceCategory] ?? 0;
      final trafficCount = features['traffic']?[trafficLevel] ?? 0;
      
      // Apply Laplace smoothing (add-1 smoothing)
      final timeOfDayLikelihood = (timeOfDayCount + 1) / (classCount + 4); // 4 possible time slots
      final dayTypeLikelihood = (dayTypeCount + 1) / (classCount + 2); // 2 possible day types
      final serviceTypeLikelihood = (serviceTypeCount + 1) / (classCount + 5); // 5 service types
      final distanceLikelihood = (distanceCount + 1) / (classCount + 3); // 3 distance categories
      final trafficLikelihood = (trafficCount + 1) / (classCount + 3); // 3 traffic levels
      
      // Multiply likelihoods (naive assumption of independence)
      likelihood = timeOfDayLikelihood * 
                  dayTypeLikelihood * 
                  serviceTypeLikelihood * 
                  distanceLikelihood * 
                  trafficLikelihood;
      
      // Calculate posterior probability (prior * likelihood)
      final posterior = prior * likelihood;
      
      // Track the class with highest probability
      if (posterior > maxProb) {
        maxProb = posterior;
        bestClass = interval;
      }
    }
    
    // Return the most likely arrival time (midpoint of the interval)
    return bestClass.toDouble() + 7.5;
  }
  
  Map<String, double> getAllPredictions(List<double> inputFeatures) {
    // Ensure we have at least 5 features (hour, day, service_type, distance, traffic)
    final paddedFeatures = List<double>.from(inputFeatures);
    while (paddedFeatures.length < 5) {
      paddedFeatures.add(1.0); // Default values for missing features
    }
    
    // Get predictions from all models
    final predictions = <String, double>{
      'Decision Tree': predictWithDecisionTree(paddedFeatures),
      'K-Nearest Neighbors': predictWithKNN(paddedFeatures),
      'SVM': predictWithSVM(paddedFeatures),
      'Neural Network': predictWithNeuralNetwork(paddedFeatures),
      'Naive Bayes': predictWithNaiveBayes(paddedFeatures),
    };
    
    // Calculate weighted average (give more weight to some models)
    final weights = <String, double>{
      'Decision Tree': 0.2,
      'K-Nearest Neighbors': 0.2,
      'SVM': 0.2,
      'Neural Network': 0.2,
      'Naive Bayes': 0.2,
    };
    
    double weightedSum = 0;
    double weightSum = 0;
    
    predictions.forEach((key, value) {
      weightedSum += value * (weights[key] ?? 0.0);
      weightSum += weights[key] ?? 0.0;
    });
    
    // Add the ensemble prediction
    final ensemblePrediction = weightedSum / weightSum;
    predictions['Ensemble'] = ensemblePrediction;
    
    return predictions;
  }
}

// Initialize the prediction model
final arrivalPredictionModel = ArrivalPredictionModels();
