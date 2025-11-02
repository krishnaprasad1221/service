import 'package:flutter/material.dart';
import 'package:servez/ml_models/arrival_prediction_models.dart';

class MLPredictionScreen extends StatefulWidget {
  const MLPredictionScreen({Key? key}) : super(key: key);

  @override
  _MLPredictionScreenState createState() => _MLPredictionScreenState();
}

class _MLPredictionScreenState extends State<MLPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _hourController = TextEditingController(text: '14');
  final _dayController = TextEditingController(text: '3');
  final _distanceController = TextEditingController(text: '10');
  final _trafficController = TextEditingController(text: '3');
  
  // Results
  Map<String, double> _predictions = {};
  
  @override
  void dispose() {
    _hourController.dispose();
    _dayController.dispose();
    _distanceController.dispose();
    _trafficController.dispose();
    super.dispose();
  }
  
  void _calculatePredictions() {
    if (!_formKey.currentState!.validate()) return;
    
    final inputFeatures = [
      double.parse(_hourController.text),
      double.parse(_dayController.text),
      double.parse(_distanceController.text),
      double.parse(_trafficController.text),
    ];
    
    setState(() {
      _predictions = ArrivalPredictionModels.getAllPredictions(inputFeatures);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Arrival Prediction'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(
                controller: _hourController,
                label: 'Hour of Day (0-23)',
                validator: (value) => _validateRange(value, 0, 23),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _dayController,
                label: 'Day of Week (1-7, 1=Monday)',
                validator: (value) => _validateRange(value, 1, 7),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _distanceController,
                label: 'Distance (km)',
                validator: (value) => _validatePositive(value),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _trafficController,
                label: 'Traffic Condition (1-5, 1=best, 5=worst)',
                validator: (value) => _validateRange(value, 1, 5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _calculatePredictions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Calculate Predictions',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),
              if (_predictions.isNotEmpty) _buildResultsCard(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      keyboardType: TextInputType.number,
      validator: validator,
    );
  }
  
  String? _validateRange(String? value, int min, int max) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    final numValue = int.tryParse(value);
    if (numValue == null) {
      return 'Please enter a valid number';
    }
    if (numValue < min || numValue > max) {
      return 'Must be between $min and $max';
    }
    return null;
  }
  
  String? _validatePositive(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    final numValue = double.tryParse(value);
    if (numValue == null) {
      return 'Please enter a valid number';
    }
    if (numValue <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }
  
  Widget _buildResultsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predicted Arrival Times (minutes):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._predictions.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.key}:',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${entry.value.toStringAsFixed(1)} min',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 16),
            const Text(
              'Note: These are dummy predictions based on sample data.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
