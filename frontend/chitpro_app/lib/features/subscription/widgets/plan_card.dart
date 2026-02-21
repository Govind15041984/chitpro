import 'package:flutter/material.dart';

class PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final bool isSelected;
  final Color themeColor;
  final bool isPopular;

  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.features,
    required this.isSelected,
    required this.themeColor,
    this.isPopular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isSelected ? themeColor : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? themeColor.withOpacity(0.15) : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular) _buildPopularBadge(),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: themeColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 32, thickness: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: features.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: themeColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          features[index],
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "RECOMMENDED",
        style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}