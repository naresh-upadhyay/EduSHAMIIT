import 'package:flutter/material.dart';

class AdmissionsTab extends StatelessWidget {
  const AdmissionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Admissions Portal',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review, approve, or reject student registration requests for the upcoming term.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),

          // Requests list
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF13182C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Admissions Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildAdmissionItem(context,
                        name: 'Aanya Sen',
                        grade: 'Class 10A',
                        email: 'aanya.sen@gmail.com',
                        city: 'Kolkata'),
                    _buildAdmissionItem(context,
                        name: 'Vikram Malhotra',
                        grade: 'Class 11A',
                        email: 'vikram.m@yahoo.com',
                        city: 'Mumbai'),
                    _buildAdmissionItem(context,
                        name: 'Rohan Deshmukh',
                        grade: 'Class 10B',
                        email: 'rohan.d@gmail.com',
                        city: 'Pune'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdmissionItem(BuildContext context,
      {required String name,
      required String grade,
      required String email,
      required String city}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$grade  •  $email  •  $city',
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Admission request rejected for $name.')),
                  );
                },
                child:
                    const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Admission approved. Welcome mail sent to $email.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
