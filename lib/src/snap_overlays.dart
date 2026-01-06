import 'package:flutter/material.dart';
import 'models.dart';

class SnapPreviewOverlay extends StatelessWidget {
  final SnapRegion region; final Size screenSize; final EdgeInsets padding;
  const SnapPreviewOverlay({super.key, required this.region, required this.screenSize, required this.padding});
  @override
  Widget build(BuildContext context) {
    Rect target; final w = screenSize.width - padding.left - padding.right; final h = screenSize.height - padding.top - padding.bottom; final startX = padding.left; final startY = padding.top; final hw = w/2, hh = h/2, tw = w/3; const p = 12.0;
    switch (region) { case SnapRegion.left: target = Rect.fromLTWH(startX+p, startY+p, hw-2*p, h-2*p); break; case SnapRegion.right: target = Rect.fromLTWH(startX+hw+p, startY+p, hw-2*p, h-2*p); break; case SnapRegion.top: target = Rect.fromLTWH(startX+p, startY+p, w-2*p, h-2*p); break; case SnapRegion.topLeft: target = Rect.fromLTWH(startX+p, startY+p, hw-2*p, hh-2*p); break; case SnapRegion.topRight: target = Rect.fromLTWH(startX+hw+p, startY+p, hw-2*p, hh-2*p); break; case SnapRegion.bottomLeft: target = Rect.fromLTWH(startX+p, startY+hh+p, hw-2*p, hh-2*p); break; case SnapRegion.bottomRight: target = Rect.fromLTWH(startX+hw+p, startY+hh+p, hw-2*p, hh-2*p); break; case SnapRegion.leftThird: target = Rect.fromLTWH(startX+p, startY+p, tw-2*p, h-2*p); break; case SnapRegion.centerThird: target = Rect.fromLTWH(startX+tw+p, startY+p, tw-2*p, h-2*p); break; case SnapRegion.rightThird: target = Rect.fromLTWH(startX+tw*2+p, startY+p, tw-2*p, h-2*p); break; default: target = Rect.zero; }
    return AnimatedPositioned(duration: const Duration(milliseconds: 150), curve: Curves.easeOutQuad, left: target.left, top: target.top, width: target.width, height: target.height, child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.5), width: 2))));
  }
}

class StaticSnapBar extends StatelessWidget {
  final SnapRegion activeRegion; const StaticSnapBar({super.key, required this.activeRegion});
  @override
  Widget build(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5))]), child: Row(mainAxisSize: MainAxisSize.min, children: [SnapIcon(Icons.splitscreen, SnapRegion.left, activeRegion), const SizedBox(width: 4), SnapIcon(Icons.splitscreen, SnapRegion.right, activeRegion, rotate: true), Container(height: 24, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 12)), SnapIcon(Icons.view_column, SnapRegion.leftThird, activeRegion), const SizedBox(width: 4), SnapIcon(Icons.view_week, SnapRegion.centerThird, activeRegion), const SizedBox(width: 4), SnapIcon(Icons.view_column, SnapRegion.rightThird, activeRegion, rotate: true), Container(height: 24, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 12)), SnapIcon(Icons.crop_square, SnapRegion.top, activeRegion)])); }
}

class SnapIcon extends StatelessWidget {
  final IconData icon; final SnapRegion targetRegion; final SnapRegion activeRegion; final bool rotate;
  const SnapIcon(this.icon, this.targetRegion, this.activeRegion, {super.key, this.rotate = false});
  @override
  Widget build(BuildContext context) { final bool isActive = targetRegion == activeRegion; return AnimatedContainer(duration: const Duration(milliseconds: 100), width: 44, height: 44, decoration: BoxDecoration(color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isActive ? Colors.blueAccent : Colors.transparent, width: 2)), child: Transform.rotate(angle: rotate ? 3.14 : 0, child: Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey[500], size: 22))); }
}