import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/log_pilot_controller.dart';
import 'src/screens/log_list_screen.dart';

void main() {
  runApp(const LogPilotDevToolsExtension());
}

class LogPilotDevToolsExtension extends StatelessWidget {
  const LogPilotDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: _LogPilotExtensionBody(),
    );
  }
}

/// Created as a child of [DevToolsExtension] so that
/// `serviceManager` is already initialized when we access it.
class _LogPilotExtensionBody extends StatefulWidget {
  const _LogPilotExtensionBody();

  @override
  State<_LogPilotExtensionBody> createState() => _LogPilotExtensionBodyState();
}

class _LogPilotExtensionBodyState extends State<_LogPilotExtensionBody> {
  late final LogPilotController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LogPilotController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LogListScreen(controller: _controller);
  }
}
