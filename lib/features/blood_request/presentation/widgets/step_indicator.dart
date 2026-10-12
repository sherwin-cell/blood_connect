import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart'; // Adjust path if needed

class StepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, 3, or 4

  const StepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepItem(1, 'Patient Info', currentStep),
        _buildDivider(),
        _buildStepItem(2, 'Blood Details', currentStep),
        _buildDivider(),
        _buildStepItem(3, 'Hospital Info', currentStep),
        _buildDivider(),
        _buildStepItem(4, 'Review', currentStep),
      ],
    );
  }

  Widget _buildStepItem(int stepNumber, String title, int currentStep) {
    bool isActive = stepNumber == currentStep;
    bool isCompleted = stepNumber < currentStep;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? AppColors.primaryRed
                : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primaryRed : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 2,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
