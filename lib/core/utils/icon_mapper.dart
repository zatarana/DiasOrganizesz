import 'package:flutter/material.dart';

class IconMapper {
  static IconData fromName(String? name) {
    switch (name) {
      case 'attach_money':
        return Icons.attach_money;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'subscriptions':
        return Icons.subscriptions;
      case 'money_off':
        return Icons.money_off;
      case 'trending_up':
        return Icons.trending_up;
      case 'work':
        return Icons.work;
      case 'person':
        return Icons.person;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'category':
      default:
        return Icons.category;
    }
  }
}
