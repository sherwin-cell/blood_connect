import 'package:flutter/material.dart';

class DonorStepIndicator extends StatelessWidget {
  final int currentStep;

  const DonorStepIndicator({super.key, required this.currentStep});

  static const Color donorGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem(stepNumber: 1, title: 'Personal Info'),
        _buildDivider(),
        _buildStepItem(stepNumber: 2, title: 'Blood & History'),
        _buildDivider(),
        _buildStepItem(stepNumber: 3, title: 'Health Screening'),
        _buildDivider(),
        _buildStepItem(stepNumber: 4, title: 'Review'),
      ],
    );
  }

  Widget _buildStepItem({required int stepNumber, required String title}) {
    final bool isActive = stepNumber == currentStep;
    final bool isCompleted = stepNumber < currentStep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? donorGreen : Colors.grey.shade200,
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
            color: isActive ? donorGreen : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 4, right: 4, top: 13),
        color: Colors.grey.shade300,
      ),
    );
  }
}
