// lib/widgets/draggable_resizable.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DraggableResizable extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Color? color;

  const DraggableResizable({
    Key? key,
    required this.docId,
    required this.data,
    this.color,
  }) : super(key: key);

  @override
  State<DraggableResizable> createState() => _DraggableResizableState();
}

class _DraggableResizableState extends State<DraggableResizable> {
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

  void _updateFirestore() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chairs')
        .doc(widget.docId)
        .update({
        'position': {'x': x, 'y': y},
        'size':     {'width': width, 'height': height},
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
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
              color: widget.color ?? Colors.blue.withOpacity(0.3),
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
                child: const Icon(Icons.open_with, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

