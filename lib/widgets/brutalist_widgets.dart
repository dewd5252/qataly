import 'package:flutter/material.dart';

class BrutalistCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double shadowOffset;
  final Color shadowColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const BrutalistCard({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF1E1E24),
    this.shadowOffset = 4.0,
    this.shadowColor = Colors.black,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: Offset(shadowOffset, shadowOffset),
            blurRadius: 0.0,
            spreadRadius: 0.0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

class BrutalistButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color backgroundColor;
  final double shadowOffset;
  final Color shadowColor;
  final double height;
  final double? width;
  final EdgeInsetsGeometry padding;

  const BrutalistButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor = const Color(0xFF7C3AED),
    this.shadowOffset = 4.0,
    this.shadowColor = Colors.black,
    this.height = 50.0,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  State<BrutalistButton> createState() => _BrutalistButtonState();
}

class _BrutalistButtonState extends State<BrutalistButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final offset = _isPressed ? 1.0 : widget.shadowOffset;
    final translateOffset = _isPressed ? widget.shadowOffset - 1.0 : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: Offset(translateOffset, translateOffset),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(color: Colors.black, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor,
                offset: Offset(offset, offset),
                blurRadius: 0.0,
                spreadRadius: 0.0,
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16.0,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class BrutalistInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const BrutalistInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0.0,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white38),
          fillColor: const Color(0xFF1E1E24),
          filled: true,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.white70) : null,
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.black, width: 2.0),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.black, width: 2.0),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.black, width: 2.5),
          ),
          errorStyle: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
