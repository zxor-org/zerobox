import 'package:flutter/widgets.dart';

class SecondaryWindowHost extends StatelessWidget {
  const SecondaryWindowHost({
    super.key,
    required this.role,
    required this.child,
  });
  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
