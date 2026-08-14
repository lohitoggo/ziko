import 'package:flutter/material.dart';

class RestaurantProfileTab extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantProfileTab({
    super.key,
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        const CircleAvatar(
          radius: 50,
          child: Icon(Icons.restaurant,size:50),
        ),

        const SizedBox(height:20),

        Card(
          child: ListTile(
            leading: const Icon(Icons.store),
            title: const Text("Restaurant"),
            subtitle: Text(restaurant["name"] ?? ""),
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text("Area"),
            subtitle: Text(restaurant["areaName"] ?? ""),
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.phone),
            title: const Text("Phone"),
            subtitle: Text(restaurant["phone"] ?? ""),
          ),
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.star),
            title: const Text("Rating"),
            subtitle: Text(
                "${restaurant["avgRating"] ?? 0}"),
          ),
        ),

        const SizedBox(height:20),

        ElevatedButton.icon(
          onPressed: () {

            // Edit Restaurant

          },
          icon: const Icon(Icons.edit),
          label: const Text("Edit Restaurant"),
        )

      ],
    );
  }
}