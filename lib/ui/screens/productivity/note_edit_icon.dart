import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoteEditIcon extends StatelessWidget {
  const NoteEditIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/vectors/edit_note.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
}
