// lib/widgets/layout_draggable.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LayoutDraggable extends StatefulWidget {
  final DocumentReference docRef;
  final Map<String, dynamic> data;
  final Color color;
  final VoidCallback? onTap;            // <— nuevo

  const LayoutDraggable({
    Key? key,
    required this.docRef,
    required this.data,
    required this.color,
    this.onTap,                         // <— nuevo
  }) : super(key: key);

  @override
  State<LayoutDraggable> createState() => _LayoutDraggableState();
}

class _LayoutDraggableState extends State<LayoutDraggable> {
  late double x, y, width, height;

  @override
  void initState() {
    super.initState();
    final pos = widget.data['position'] as Map<String, dynamic>;
    final sz  = widget.data['size']     as Map<String, dynamic>;
    x      = (pos['x']   as num).toDouble();
    y      = (pos['y']   as num).toDouble();
    width  = (sz['width']  as num).toDouble();
    height = (sz['height'] as num).toDouble();
  }

  Future<void> _updateFirestore() async {
    try {
      await widget.docRef.update({
        'position': {'x': x, 'y': y},
        'size':     {'width': width, 'height': height},
      });
    } catch (e) {
      debugPrint('Error actualizando layout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: widget.onTap,             // <— manejamos el tap aquí
        onPanUpdate: (e) {
          setState(() {
            x += e.delta.dx;
            y += e.delta.dy;
          });
        },
        onPanEnd: (_) => _updateFirestore(),
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.4),
                border: Border.all(color: widget.color, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.data['name'] as String,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (e) {
                  setState(() {
                    width  = (width  + e.delta.dx).clamp(30.0, 500.0);
                    height = (height + e.delta.dy).clamp(30.0, 500.0);
                  });
                },
                onPanEnd: (_) => _updateFirestore(),
                child: Icon(Icons.open_with, size: 20, color: widget.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

