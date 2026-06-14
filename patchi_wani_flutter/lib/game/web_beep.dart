// Web-only: calls patchiWaniPlayBeep() defined in web/index.html.
import 'dart:js_interop';

@JS('patchiWaniPlayBeep')
external void _jsPlayBeep();

void playWebBeep() => _jsPlayBeep();
