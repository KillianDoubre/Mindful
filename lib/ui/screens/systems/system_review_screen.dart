import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';

class SystemReviewScreen extends ConsumerStatefulWidget {
  const SystemReviewScreen({super.key, required this.systemId});

  final int systemId;

  @override
  ConsumerState<SystemReviewScreen> createState() => _SystemReviewScreenState();
}

class _SystemReviewScreenState extends ConsumerState<SystemReviewScreen> {
  final _proof = TextEditingController();
  final _natural = TextEditingController();
  final _resistance = TextEditingController();
  final _friction = TextEditingController();
  final _commitment = TextEditingController();
  bool _express = true;
  bool _saving = false;
  String _resistanceSource = 'Effort';
  LifeSystemStatus _decision = LifeSystemStatus.active;
  int? _initializedSystemId;

  @override
  void dispose() {
    _proof.dispose();
    _natural.dispose();
    _resistance.dispose();
    _friction.dispose();
    _commitment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final system = _findSystem(ref.watch(systemsProvider).valueOrNull);
    if (system != null && _initializedSystemId != system.id) {
      _decision = system.status;
      _initializedSystemId = system.id;
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Revue du système'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Reporter'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MindfulBackground(),
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              GlassSurface(
                showShadow: false,
                padding: const EdgeInsets.all(17),
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system?.name ?? 'Système',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Il ne s’agit pas de te noter, mais de rendre le système plus praticable.',
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Express')),
                        ButtonSegment(value: false, label: Text('Complète')),
                      ],
                      selected: {_express},
                      onSelectionChanged: (value) =>
                          setState(() => _express = value.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ReviewField(
                controller: _proof,
                title: 'Quelles preuves d’identité ai-je produites ?',
                hint: 'Les actions réelles, même modestes…',
              ),
              if (!_express)
                _ReviewField(
                  controller: _natural,
                  title: 'Quelle victoire a été la plus naturelle ?',
                  hint: 'Ce qui s’est intégré facilement à la semaine…',
                ),
              _ReviewField(
                controller: _resistance,
                title: 'Où ai-je ressenti le plus de résistance ?',
                hint: 'Un moment, une action ou un contexte précis…',
              ),
              if (!_express) ...[
                GlassSurface(
                  showShadow: false,
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(22),
                  child: DropdownButtonFormField<String>(
                    initialValue: _resistanceSource,
                    decoration: const InputDecoration(
                      labelText: 'Cette résistance vient surtout de…',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'Effort',
                      'Environnement',
                      'Manque de clarté',
                      'Manque de sens',
                      'Manque de soutien extérieur',
                    ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _resistanceSource = value ?? _resistanceSource,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ReviewField(
                  controller: _friction,
                  title: 'Quelle friction puis-je modifier ?',
                  hint: 'Une expérience simple pour la prochaine période…',
                ),
                GlassSurface(
                  showShadow: false,
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(22),
                  child: DropdownButtonFormField<LifeSystemStatus>(
                    initialValue: _decision,
                    decoration: const InputDecoration(
                      labelText: 'Décision pour ce système',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: LifeSystemStatus.active,
                        child: Text('Conserver actif'),
                      ),
                      DropdownMenuItem(
                        value: LifeSystemStatus.maintenance,
                        child: Text('Passer en entretien'),
                      ),
                      DropdownMenuItem(
                        value: LifeSystemStatus.paused,
                        child: Text('Suspendre sans perdre l’élan'),
                      ),
                      DropdownMenuItem(
                        value: LifeSystemStatus.draft,
                        child: Text('Réviser en brouillon'),
                      ),
                      DropdownMenuItem(
                        value: LifeSystemStatus.archived,
                        child: Text('Archiver'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _decision = value ?? _decision),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _ReviewField(
                controller: _commitment,
                title: 'Quel est mon prochain engagement concret ?',
                hint: 'Une action claire et contrôlable…',
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed:
                    _saving || system == null ? null : () => _save(system),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.checkmark_20_filled),
                label: const Text('Enregistrer la revue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LifeSystem? _findSystem(List<LifeSystem>? systems) {
    for (final system in systems ?? const <LifeSystem>[]) {
      if (system.id == widget.systemId) return system;
    }
    return null;
  }

  Future<void> _save(LifeSystem system) async {
    if (_proof.text.trim().isEmpty ||
        _resistance.text.trim().isEmpty ||
        _commitment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complète les trois questions essentielles.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final reflection = [
      'Preuves : ${_proof.text.trim()}',
      if (!_express) 'Victoire naturelle : ${_natural.text.trim()}',
      'Résistance : ${_resistance.text.trim()}',
      if (!_express) 'Source : $_resistanceSource',
      if (!_express && _friction.text.trim().isNotEmpty)
        'Friction à tester : ${_friction.text.trim()}',
      'Prochain engagement : ${_commitment.text.trim()}',
    ].join('\n');
    await ref.read(systemsProvider.notifier).recordReview(
          systemId: system.id,
          reflection: reflection,
          isExpress: _express,
        );
    if (!_express && _decision != system.status) {
      await ref
          .read(systemsProvider.notifier)
          .changeStatus(system.id, _decision);
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _ReviewField extends StatelessWidget {
  const _ReviewField({
    required this.controller,
    required this.title,
    required this.hint,
  });

  final TextEditingController controller;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassSurface(
          showShadow: false,
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
