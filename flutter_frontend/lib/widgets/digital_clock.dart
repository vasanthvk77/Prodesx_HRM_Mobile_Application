import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key});

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  String _currentTime = '';
  String _currentDay = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm a').format(now);
        _currentDay = DateFormat('EEEE').format(now);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currentTime,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          _currentDay,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
