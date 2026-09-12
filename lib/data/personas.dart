import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Persona {
  final String name;
  final String initials;
  final Color color;
  const Persona(this.name, this.initials, this.color);
}

/// Assigned round-robin to freshly signed-in (anonymous) users so that
/// opening the app in a few different browser tabs demonstrates real
/// multi-user presence instead of everyone showing up as "You".
const personaPool = [
  Persona('Ana Ruiz', 'AR', AppColors.primary),
  Persona('Milo Sato', 'MS', AppColors.priorityHigh),
  Persona('Jun Lee', 'JL', AppColors.priorityLow),
  Persona('Rae Kim', 'RK', AppColors.priorityMedium),
  Persona('Theo Cole', 'TC', AppColors.accentPink),
  Persona('Sam Ortiz', 'SO', AppColors.accentOrange),
  Persona('Priya Nair', 'PN', AppColors.accentAmberDeep),
  Persona('Wren Fields', 'WF', AppColors.primaryLight),
];
