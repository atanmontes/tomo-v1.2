import 'package:flutter/material.dart';

const Color tomoPink = Color(0xFFEC4899);
const Color tomoPinkSoft = Color(0x33EC4899);
const Color tomoBackground = Color(0xFF070709);
const Color tomoCard = Color(0xFF141418);
const Color tomoElevated = Color(0xFF1B1B21);
const Color tomoLine = Color(0x14FFFFFF);

ThemeData tomoTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: tomoBackground,
    // Eliminamos los splashes globales
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tomoPink,
      brightness: Brightness.dark,
    ).copyWith(
      primary: tomoPink,
      surface: tomoCard,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: tomoBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: Colors.white,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tomoElevated,
      // 1. Quita la píldora/rectángulo de selección de fondo
      indicatorColor: Colors.transparent, 
      // 2. Desactiva el overlay/ripple de toque en los ítems del menú
      overlayColor: WidgetStateProperty.all(Colors.transparent), 
      // 3. Cambia los colores de los iconos (rosa si está seleccionado, blanco tenue si no)
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? tomoPink : Colors.white54,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? tomoPink : Colors.white54,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tomoElevated,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: tomoPink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: tomoLine,
  );
}