import 'dart:math';

class ArrivalPredictionModels {
  // Format: [hour_of_day, day_of_week, service_type(1-5), distance_km, 
  //          traffic_condition(1-5), provider_availability(0-1), 
  //          historical_avg_arrival_min, is_weekend(0/1), 
  //          time_slot(0=morning,1=afternoon,2=evening,3=night)]
  static final List<List<double>> _trainingData = [
    [9, 1, 2, 5.0, 3, 1, 20, 0, 0],  // Monday morning, service type 2
    [14, 2, 1, 10.0, 4, 0.8, 35, 0, 1], // Tuesday afternoon, service type 1
    [18, 5, 3, 15.0, 5, 0.6, 50, 1, 2], // Friday evening, service type 3
    [11, 3, 4, 2.0, 2, 0.9, 10, 0, 0], // Wednesday morning, service type 4
    [16, 4, 2, 8.0, 3, 0.7, 30, 0, 1], // Thursday afternoon, service type 2
    [10, 6, 1, 12.0, 4, 0.5, 40, 1, 0], // Saturday morning, service type 1
    [13, 7, 5, 7.0, 3, 0.4, 25, 1, 1], // Sunday afternoon, service type 5
    [17, 3, 3, 20.0, 5, 0.8, 60, 0, 2], // Wednesday evening, service type 3
    [9, 5, 2, 3.0, 2, 0.7, 12, 0, 0],  // Friday morning, service type 2
    [15, 4, 4, 9.0, 4, 0.6, 32, 0, 1],  // Thursday afternoon, service type 4
  ];
  
  // Service type weights (how much each service type affects allocation time)
  static const Map<int, double> _serviceTypeWeights = {
    1: 1.2, // Emergency service - higher priority
    2: 1.0, // Standard service
    3: 0.8, // Scheduled maintenance
    4: 1.1, // Premium service
    5: 0.9, // Basic service
  };
  
  // Time slot weights (morning, afternoon, evening, night)
  static const List<double> _timeSlotWeights = [1.1, 1.0, 0.9, 1.3];


  static double predictWithKNN(List<double> inputFeatures, {int k = 3}) {
    final distances = <_DistanceIndex>[];
    final serviceType = inputFeatures[2].toInt();
    
    for (int i = 0; i < _trainingData.length; i++) {
      final data = _trainingData[i];
      // Compare only relevant features: hour, day, service type, distance, traffic
      final features = data.sublist(0, 5);
      double distance = 0;
      
      // Calculate weighted Euclidean distance
      for (int j = 0; j < inputFeatures.length && j < 5; j++) {
        // Apply higher weight to service type and traffic
        final weight = (j == 2 || j == 4) ? 1.5 : 1.0;
        distance += weight * pow(inputFeatures[j] - features[j], 2);
      }
      distance = sqrt(distance);
      
      // Adjust distance based on provider availability
      final availability = data[5];
      distance *= (1.2 - (availability * 0.3)); // Lower distance for better availability
      
      distances.add(_DistanceIndex(distance, i));
    }
    
    // Sort by distance and get k nearest neighbors
    distances.sort((a, b) => a.distance.compareTo(b.distance));
    
    // Calculate weighted average arrival time of k nearest neighbors
    double sum = 0;
    double weightSum = 0;
    
    for (int i = 0; i < k && i < distances.length; i++) {
      final idx = distances[i].index;
      final data = _trainingData[idx];
      final serviceType = data[2].toInt();
      final weight = 1 / (1 + distances[i].distance); 
      
      // Adjust prediction based on service type and time slot
      final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
      final timeSlot = data[8].toInt();
      final timeWeight = timeSlot < _timeSlotWeights.length ? _timeSlotWeights[timeSlot] : 1.0;
      
      sum += data[6] * weight * serviceWeight * timeWeight;
      weightSum += weight;
    }
    
    // Apply service type specific adjustment
    final basePrediction = sum / weightSum;
    final serviceAdjustment = _serviceTypeWeights[serviceType] ?? 1.0;
    return (basePrediction * serviceAdjustment).clamp(10.0, 240.0); // Clamp between 10-240 minutes
  }
  
  // Decision Tree implementation for service allocation
  static double predictWithDecisionTree(List<double> inputFeatures) {
    final hour = inputFeatures[0];
    final day = inputFeatures[1];
    final serviceType = inputFeatures[2].toInt();
    final distance = inputFeatures[3];
    final traffic = inputFeatures[4];
    
    // Service type adjustment
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Determine time slot
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
    
    // Base time based on time slot
    double baseTime;
    switch (timeSlot) {
      case 0: // Morning
        baseTime = distance * 2.5;
        break;
      case 1: // Afternoon
        baseTime = distance * 2.0;
        break;
      case 2: // Evening
        baseTime = distance * 3.0;
        break;
      case 3: // Night
        baseTime = distance * 3.5;
        break;
      default:
        baseTime = distance * 2.5;
    }
    
    // Adjust for traffic
    double trafficFactor;
    if (traffic < 2) {
      trafficFactor = 1.0;
    } else if (traffic < 4) {
      trafficFactor = 1.3;
    } else {
      trafficFactor = 1.7;
    }
    
    // Adjust for weekend
    final isWeekend = (day >= 6) ? 1.2 : 1.0;
    
    // Final calculation
    return (baseTime * trafficFactor * isWeekend * serviceWeight).clamp(10.0, 240.0);
  }
  
  // SVM implementation for service allocation
  static double predictWithSVM(List<double> inputFeatures) {
    // Feature weights: [hour, day, service_type, distance, traffic]
    // Higher weights for service type and traffic
    final weights = <double>[0.3, 0.2, 1.5, 0.8, 1.2];
    final bias = 10.0; // Base time
    
    // Apply feature scaling
    final scaledFeatures = List<double>.from(inputFeatures);
    // Scale hour to 0-1 (assuming 24h format)
    scaledFeatures[0] = inputFeatures[0] / 24.0;
    // Scale day to 0-1 (1=Monday to 7=Sunday)
    scaledFeatures[1] = (inputFeatures[1] - 1) / 6.0;
    // Service type is already categorical
    // Scale distance (assuming max 50km)
    scaledFeatures[3] = inputFeatures[3] / 50.0;
    // Scale traffic (1-5 to 0-1)
    scaledFeatures[4] = (inputFeatures[4] - 1) / 4.0;
    
    final features = List<double>.from(scaledFeatures);
    
    // Calculate prediction with bias using a simple dot product
    double prediction = _dot(weights, features) + bias;
    
    // Apply service type specific adjustment
    final serviceType = inputFeatures[2].toInt();
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Convert back to minutes and apply service weight
    prediction = prediction * 30.0 * serviceWeight;
    
    // Ensure reasonable bounds
    return prediction.clamp(10.0, 240.0);
  }
  
  // Neural Network implementation for service allocation
  static double predictWithNeuralNetwork(List<double> inputFeatures) {
    // Normalize input features
    final normalized = _normalizeFeatures(inputFeatures);
    final input = List<double>.from(normalized);
    
    // First hidden layer (5 input features -> 4 hidden units)
    final w1 = <List<double>>[
      [0.2, 0.3, 0.1, 0.4, 0.2],
      [0.1, 0.2, 0.3, 0.1, 0.3],
      [0.3, 0.1, 0.4, 0.2, 0.1],
      [0.1, 0.3, 0.2, 0.3, 0.2],
    ];
    final b1 = <double>[0.1, 0.1, 0.1, 0.1];
    
    // Second hidden layer (4 -> 3 hidden units)
    final w2 = <List<double>>[
      [0.4, 0.3, 0.2, 0.1],
      [0.3, 0.2, 0.4, 0.3],
      [0.2, 0.4, 0.3, 0.2],
    ];
    final b2 = <double>[0.1, 0.1, 0.1];
    
    // Output layer (3 -> 1 output)
    final w3 = <double>[0.4, 0.3, 0.3];
    const b3 = 0.1;
    
    // Forward pass with ReLU activation
    final hidden1 = _applyReLU(_vectorAdd(_matrixVectorProduct(w1, input), b1));
    final hidden2 = _applyReLU(_vectorAdd(_matrixVectorProduct(w2, hidden1), b2));
    var output = _dot(hidden2, w3) + b3;
    
    // Apply service type specific adjustment
    final serviceType = inputFeatures[2].toInt();
    final serviceWeight = _serviceTypeWeights[serviceType] ?? 1.0;
    
    // Scale to minutes and apply service weight
    output = (output * 100 + 30) * serviceWeight;
    
    // Ensure reasonable bounds (10-240 minutes)
    return output.clamp(10.0, 240.0);
  }
  
  // Helper method to normalize features
  static List<double> _normalizeFeatures(List<double> features) {
    // Normalize each feature to 0-1 range
    final normalized = List<double>.from(features);
    
    // Hour (0-23) -> 0-1
    normalized[0] = features[0] / 23.0;
    
    // Day (1-7) -> 0-1
    normalized[1] = (features[1] - 1) / 6.0;
    
    // Service type (1-5) -> 0-1
    normalized[2] = (features[2] - 1) / 4.0;
    
    // Distance (0-50km) -> 0-1 (assuming max 50km)
    normalized[3] = features[3] / 50.0;
    
    // Traffic (1-5) -> 0-1
    normalized[4] = (features[4] - 1) / 4.0;
    
    return normalized;
  }
  
  // Naive Bayes Classifier for service allocation
  static double predictWithNaiveBayes(List<double> inputFeatures) {
    // Categorize allocation times into 4 classes based on service level agreement (SLA)
    final classRanges = [
      {'min': 0.0, 'max': 30.0, 'label': 'Fast'},      // 0-30 min (Premium)
      {'min': 30.0, 'max': 90.0, 'label': 'Standard'},  // 30-90 min (Standard)
      {'min': 90.0, 'max': 180.0, 'label': 'Delayed'},  // 1.5-3 hours (Delayed)
      {'min': 180.0, 'max': double.infinity, 'label': 'Extended'}, // 3+ hours (Extended)
    ];
    
    // Count occurrences of each class
    final classCounts = <String, int>{};
    final featureMeans = <String, List<double>>{};
    final featureStds = <String, List<double>>{};
    
    // Initialize data structures
    for (final range in classRanges) {
      final label = range['label'] as String;
      classCounts[label] = 0;
      featureMeans[label] = List.filled(4, 0.0); // 4 features
      featureStds[label] = List.filled(4, 0.0);
    }
    
    // First pass: count class occurrences
    for (final data in _trainingData) {
      final arrivalTime = data[4];
      String? dataClass;
      
      for (final range in classRanges) {
        final minVal = range['min'] as double;
        final maxVal = range['max'] as double;
        if (arrivalTime >= minVal && arrivalTime < maxVal) {
          dataClass = range['label'] as String;
          break;
        }
      }
      
      if (dataClass != null) {
        classCounts[dataClass] = (classCounts[dataClass] ?? 0) + 1;
      }
    }
    
    // Calculate priors
    final totalSamples = _trainingData.length.toDouble();
    final priors = <String, double>{};
    classCounts.forEach((label, count) {
      priors[label] = count / totalSamples;
    });
    
    // Calculate means for each feature per class
    final featureSums = <String, List<double>>{};
    final featureSquaredSums = <String, List<double>>{};
    
    for (final data in _trainingData) {
      final features = data.sublist(0, 4);
      final arrivalTime = data[4];
      String? dataClass;
      
      for (final range in classRanges) {
        final minVal = range['min'] as double;
        final maxVal = range['max'] as double;
        if (arrivalTime >= minVal && arrivalTime < maxVal) {
          dataClass = range['label'] as String;
          break;
        }
      }
      
      if (dataClass != null) {
        if (!featureSums.containsKey(dataClass)) {
          featureSums[dataClass] = List.filled(4, 0.0);
          featureSquaredSums[dataClass] = List.filled(4, 0.0);
        }
        
        for (int i = 0; i < 4; i++) {
          featureSums[dataClass]![i] += features[i];
          featureSquaredSums[dataClass]![i] += features[i] * features[i];
        }
      }
    }
    
    // Calculate means and standard deviations
    final classStats = <String, Map<String, dynamic>>{};
    
    for (final label in classCounts.keys) {
      final count = classCounts[label]!.toDouble();
      final means = <double>[];
      final stds = <double>[];
      
      for (int i = 0; i < 4; i++) {
        final mean = featureSums[label]![i] / count;
        final variance = (featureSquaredSums[label]![i] / count) - (mean * mean);
        final std = sqrt(variance);
        
        means.add(mean);
        stds.add(std > 0 ? std : 1.0); // Avoid division by zero
      }
      
      classStats[label] = {
        'mean': means,
        'std': stds,
        'prior': priors[label]!,
      };
    }
    
    // Calculate probabilities for each class
    final classProbabilities = <String, double>{};
    
    for (final label in classStats.keys) {
      double probability = log(classStats[label]!['prior']);
      
      for (int i = 0; i < 4; i++) {
        final mean = classStats[label]!['mean'][i];
        final std = classStats[label]!['std'][i];
        final x = inputFeatures[i];
        
        // Calculate Gaussian probability
        final exponent = -pow(x - mean, 2) / (2 * std * std);
        final gaussian = (1 / (sqrt(2 * pi) * std)) * exp(exponent);
        
        // Avoid log(0)
        probability += log(max(gaussian, 1e-10));
      }
      
      classProbabilities[label] = probability;
    }
    
    // Find the most probable class
    String predictedClass = '';
    double maxProb = double.negativeInfinity;
    
    classProbabilities.forEach((label, prob) {
      if (prob > maxProb) {
        maxProb = prob;
        predictedClass = label;
      }
    });
    
    // Return the midpoint of the predicted class range as the estimated time
    for (final range in classRanges) {
      if (range['label'] == predictedClass) {
        final minVal = range['min'] as double;
        final maxVal = range['max'] as double;
        final cappedMax = maxVal <= 120.0 ? maxVal : 120.0;
        return (minVal + cappedMax) / 2; // Cap at 120 minutes
      }
    }
    
    // Default fallback
    return 30.0;
  }
  
  static Map<String, double> getAllPredictions(List<double> inputFeatures) {
    // Ensure we have at least 5 features (hour, day, service_type, distance, traffic)
    final paddedFeatures = List<double>.from(inputFeatures);
    while (paddedFeatures.length < 5) {
      paddedFeatures.add(1.0); // Default values for missing features
    }
    
    // Get predictions from all models
    final predictions = {
      'KNN': predictWithKNN(paddedFeatures),
      'Decision Tree': predictWithDecisionTree(paddedFeatures),
      'SVM': predictWithSVM(paddedFeatures),
      'Neural Network': predictWithNeuralNetwork(paddedFeatures),
      'Naive Bayes': predictWithNaiveBayes(paddedFeatures),
    };
    
    // Calculate weighted average (give more weight to some models)
    final weights = {
      'KNN': 0.15,
      'Decision Tree': 0.2,
      'SVM': 0.2,
      'Neural Network': 0.3,
      'Naive Bayes': 0.15,
    };
    
    double weightedSum = 0;
    double weightSum = 0;
    
    predictions.forEach((key, value) {
      weightedSum += value * weights[key]!;
      weightSum += weights[key]!;
    });
    
    // Add the ensemble prediction
    final ensemblePrediction = weightedSum / weightSum;
    predictions['Ensemble'] = ensemblePrediction;
    
    return predictions;
  }

  // ---- Simple linear algebra helpers (to avoid external ml_linalg dependency) ----

  static double _dot(List<double> a, List<double> b) {
    final length = min(a.length, b.length);
    double sum = 0;
    for (var i = 0; i < length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  static List<double> _vectorAdd(List<double> a, List<double> b) {
    final length = min(a.length, b.length);
    return List<double>.generate(length, (i) => a[i] + b[i]);
  }

  static List<double> _applyReLU(List<double> v) {
    return v.map((x) => x > 0 ? x : 0.0).toList();
  }

  static List<double> _matrixVectorProduct(List<List<double>> m, List<double> v) {
    return m
        .map((row) => _dot(row, v))
        .toList(growable: false);
  }
}

class _DistanceIndex {
  final double distance;
  final int index;
  
  _DistanceIndex(this.distance, this.index);
}
