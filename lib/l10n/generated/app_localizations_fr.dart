// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get mindful_tagline => 'Concentrez-vous sur ce qui compte vraiment';

  @override
  String get unlock_button_label => 'Débloquer';

  @override
  String get permission_status_off => 'Désactivé';

  @override
  String get permission_status_allowed => 'Autorisé';

  @override
  String get permission_status_not_allowed => 'Accès non autorisé';

  @override
  String get permission_button_grant_permission => 'Donner l\'autorisation';

  @override
  String get permission_button_agree_and_continue => 'Accepter et continuer';

  @override
  String get permission_button_not_now => 'Pas maintenant';

  @override
  String get permission_button_help => 'Besoin d\'aide ?';

  @override
  String get permission_sheet_privacy_info =>
      'Mindful est 100% sécurisé et fonctionne hors ligne. Nous ne collectons ni stockons aucune donnée personnelle.';

  @override
  String permission_grant_step_one(String button_label) {
    return '1. Cliquez sur le bouton $button_label.';
  }

  @override
  String get permission_grant_step_two =>
      '2. Sélectionnez Mindful sur l\'écran suivant.';

  @override
  String get permission_grant_step_three =>
      '3. Cliquez sur le bouton et activez-le comme ci-dessous.';

  @override
  String get permission_notification_title => 'Envoyer des notifications';

  @override
  String get permission_alarms_title => 'Alarmes & Rappels';

  @override
  String get permission_alarms_info =>
      'Veuillez accorder la permission de régler les alarmes et les rappels. Cela permettra à Mindful de démarrer votre horaire de coucher à l\'heure, de réinitialiser les minuteurs de l\'application tous les jours à minuit et de vous aider à rester sur la bonne voie.';

  @override
  String get permission_alarms_device_tile_label =>
      'Autoriser à définir des alarmes et des rappels';

  @override
  String get permission_usage_title => 'Accès aux données d\'utilisation';

  @override
  String get permission_usage_info =>
      'Veuillez accorder l\'autorisation d\'accès aux données d\'utilisation. Cela permettra à Mindful de surveiller l\'utilisation des applications et de gérer l\'accès à certaines applications, pour un environnement numérique plus contrôlé et propice à la concentration.';

  @override
  String get permission_usage_device_tile_label =>
      'Autoriser l\'accès aux données d\'utilisation';

  @override
  String get permission_overlay_title => 'Afficher la superposition';

  @override
  String get permission_overlay_info =>
      'Veuillez accorder la permission d\'afficher la superposition. Cela permettra à Mindful d\'afficher une surcouche quand une application en pause est ouverte, ce qui vous aidera à rester concentré et à maintenir votre planning.';

  @override
  String get permission_overlay_device_tile_label =>
      'Autoriser la superposition sur d\'autres applis';

  @override
  String get permission_accessibility_title => 'Accessibilité';

  @override
  String get permission_accessibility_info =>
      'Veuillez accorder l\'autorisation d\'accessibilité. Cela permettra à Mindful de restreindre l\'accès au contenu vidéo court (ex : Reels, Shorts) dans les applications de réseaux sociaux et les navigateurs, et filtrer les sites Web inappropriés.';

  @override
  String get permission_accessibility_required =>
      'Mindful a besoin des permissions d\'accessibilité pour mieux bloquer les sites internet et les formats courts.';

  @override
  String get permission_accessibility_device_tile_label => 'Utiliser Mindful';

  @override
  String get permission_dnd_title => 'Ne pas déranger';

  @override
  String get permission_dnd_info =>
      'Veuillez autoriser l\'accès au mode Ne pas déranger. Cela permettra à Mindful de démarrer et d\'arrêter le mode Ne pas déranger pendant l\'horaire du sommeil.';

  @override
  String get permission_dnd_tile_title => 'Lancer Ne pas déranger';

  @override
  String get permission_dnd_tile_subtitle =>
      'Activer aussi le mode Ne pas déranger.';

  @override
  String get permission_battery_optimization_tile_title =>
      'Désactiver l\'optimisation de la batterie';

  @override
  String get permission_battery_optimization_status_enabled =>
      'Déjà non restreint';

  @override
  String get permission_battery_optimization_status_disabled =>
      'Désactiver la restriction d\'arrière-plan';

  @override
  String get permission_battery_optimization_allow_info =>
      'Autoriser la désactivation de l\'optimisation de la batterie accordera automatiquement la permission \'Alarmes & Rappels\' sur certains appareils.';

  @override
  String get permission_vpn_title => 'Créer un VPN';

  @override
  String get permission_vpn_info =>
      'Veuillez accorder la permission de créer une connexion au réseau privé virtuel (VPN). Cela permettra à Mindful de restreindre l\'accès à Internet pour les applications désignées en créant un VPN local sur le périphérique.';

  @override
  String get permission_admin_title => 'Admin';

  @override
  String get permission_admin_info =>
      'Les privilèges d\'administration ne sont nécessaires que pour les opérations essentielles afin de s\'assurer que l\'application fonctionne correctement et reste protégée contre les modifications.';

  @override
  String get permission_admin_snack_alert =>
      'La protection contre les modifications ne peut être désactivée que dans la plage horaire sélectionnée.';

  @override
  String get permission_notification_access_title => 'Accès aux notifications';

  @override
  String get permission_notification_access_info =>
      'Veuillez accorder l\'autorisation d\'accès aux notifications. Cela permettra à Mindful d\'organiser vos notifications et de les envoyer selon votre planning.';

  @override
  String get permission_notification_access_required =>
      'Mindful nécessite un accès aux notifications pour regrouper et planifier les notifications.';

  @override
  String get permission_notification_access_device_tile_label =>
      'Autoriser l\'accès aux notifications';

  @override
  String get day_today => 'Aujourd’hui';

  @override
  String get day_yesterday => 'Hier';

  @override
  String nDays(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jours',
      one: '1 jour',
      zero: '0 jour',
    );
    return '$_temp0';
  }

  @override
  String nHours(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString heures',
      one: '1 heure',
      zero: '0 heure',
    );
    return '$_temp0';
  }

  @override
  String nMinutes(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString minutes',
      one: '1 minute',
      zero: '0 minute',
    );
    return '$_temp0';
  }

  @override
  String nSeconds(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString secondes',
      one: '1 seconde',
      zero: '0 seconde',
    );
    return '$_temp0';
  }

  @override
  String get time_separator_and => 'et';

  @override
  String get timer_status_active => 'Activé';

  @override
  String get timer_status_paused => 'En pause';

  @override
  String get create_button => 'Créer';

  @override
  String get update_button => 'Mettre à jour';

  @override
  String get dialog_button_cancel => 'Annuler';

  @override
  String get dialog_button_remove => 'Supprimer';

  @override
  String get dialog_button_set => 'Définir';

  @override
  String get dialog_button_reset => 'Réinitialiser';

  @override
  String get dialog_button_infinite => 'Infini';

  @override
  String get schedule_start_label => 'Démarrer';

  @override
  String get schedule_end_label => 'Fin';

  @override
  String get exit_without_saving_dialog_info =>
      'Voulez-vous vraiment quitter sans enregistrer ?';

  @override
  String get development_dialog_info =>
      'Mindful est actuellement en cours de développement et peut avoir des bugs ou des fonctionnalités incomplètes. Si vous rencontrez des problèmes, merci de les signaler pour nous aider à nous améliorer.\n\nMerci pour vos retours !';

  @override
  String get development_dialog_button_report_issue => 'Signaler un problème';

  @override
  String get development_dialog_button_close => 'Fermer';

  @override
  String get dnd_settings_tile_title => 'Paramètres \"Ne pas déranger\"';

  @override
  String get dnd_settings_tile_subtitle =>
      'Gérer quelles apps et notifications peuvent vous solliciter dans le mode Ne pas déranger.';

  @override
  String get quick_actions_heading => 'Actions rapides';

  @override
  String get select_distracting_apps_heading =>
      'Sélectionner les apps qui vous distraient';

  @override
  String get your_distracting_apps_heading => 'Apps qui vous distraient';

  @override
  String get select_more_apps_heading => 'Sélectionnez plus d\'apps';

  @override
  String get imp_distracting_apps_snack_alert =>
      'L\'ajout d\'applications système importantes à la liste des applications qui vous déconcentrent n\'est pas autorisé.';

  @override
  String get custom_apps_quick_actions_unavailable_warning =>
      'Le temps d\'écran et les restrictions ne sont pas disponibles pour cette application. Pour l\'instant, seulement la consommation de données est disponible';

  @override
  String get create_group_fab_button => 'Créer un groupe';

  @override
  String get active_period_info =>
      'Définissez une période pendant laquelle l\'accès sera autorisé. En dehors de cette période, l\'accès sera restreint.';

  @override
  String get minimum_distracting_apps_snack_alert =>
      'Sélectionnez au moins une app qui vous distrait.';

  @override
  String get operation_failed_snack_alert =>
      'L\'opération a échoué, une erreur s\'est produite !';

  @override
  String get app_restart_dialog_title => 'Redémarrage nécessaire';

  @override
  String get app_restart_dialog_info =>
      'Mindful redémarrera automatiquement à la fin du compte à rebours. Merci de patienter le temps que les modifications soient appliquées.';

  @override
  String get accessibility_tip =>
      'Vous voulez un blocage plus intelligent et plus économe en batterie ? Activez l\'autorisation d\'accessibilité pour Mindful.';

  @override
  String get battery_optimization_tip =>
      'Mindful ne fonctionne pas correctement ? Autorisez l\'option Ignorer l\'optimisation de la batterie dans les réglages pour assurer son bon fonctionnement.';

  @override
  String get invincible_mode_tip =>
      'Vous avez supprimé des restrictions par erreur ? Utilisez le mode invincible pour les verrouiller jusqu\'au lendemain ou jusqu\'à la fenêtre de modification.';

  @override
  String get glance_usage_tip =>
      'Vous voulez mieux comprendre vos habitudes ? Consultez la section Aperçu pour voir votre utilisation et votre temps d\'écran.';

  @override
  String get tamper_protection_tip =>
      'Vous désinstallez Mindful ? Utilisez la fenêtre de désinstallation pour désactiver la protection anti-modification en toute sécurité.';

  @override
  String get notification_blocking_tip =>
      'Vous voulez réduire les distractions ? Utilisez le blocage des notifications pour mettre en sourdine les applications sélectionnées.';

  @override
  String get usage_history_tip =>
      'Vous voulez analyser vos habitudes ? Consultez l\'historique d\'utilisation pour voir les tendances passées.';

  @override
  String get focus_mode_tip =>
      'Besoin de vous concentrer pleinement ? Activez le mode Concentration pour bloquer les applications et les notifications pendant vos tâches.';

  @override
  String get bedtime_reminder_tip =>
      'Vous voulez améliorer votre sommeil ? Définissez un rappel de coucher pour vous détendre chaque soir.';

  @override
  String get custom_blocking_tip =>
      'Besoin d\'une expérience personnalisée ? Créez des règles de blocage adaptées à vos besoins.';

  @override
  String get session_timeline_tip =>
      'Vous voulez suivre vos sessions de concentration ? Consultez la chronologie pour voir votre parcours.';

  @override
  String get short_content_blocking_tip =>
      'Les réseaux sociaux vous distraient ? Bloquez les shorts sur Instagram, YouTube et les autres plateformes pour rester concentré.';

  @override
  String get parental_controls_tip =>
      'Besoin d\'un contrôle ? Définissez des restrictions sur l\'appareil de votre enfant pour lui offrir une expérience plus sûre.';

  @override
  String get notification_batching_tip =>
      'Vous voulez réduire les interruptions ? Regroupez les notifications afin de les consulter en une seule fois.';

  @override
  String get notification_scheduling_tip =>
      'Besoin de mieux gérer les notifications ? Planifiez leur réception pour les applications de votre choix.';

  @override
  String get quick_focus_tile_tip =>
      'Besoin de vous concentrer rapidement ? Ajoutez la tuile Concentration rapide pour activer instantanément le mode Concentration.';

  @override
  String get app_shortcuts_tip =>
      'Vous voulez accéder rapidement aux fonctions de Mindful ? Effectuez un appui long sur l\'icône de l\'application pour afficher les raccourcis.';

  @override
  String get backup_usage_db_tip =>
      'Vous voulez conserver vos données ? Sauvegardez la base de données d\'utilisation pour protéger votre historique.';

  @override
  String get dynamic_material_color_tip =>
      'Vous voulez un thème personnalisé ? Activez les couleurs dynamiques Material You pour reprendre celles de votre appareil.';

  @override
  String get amoled_dark_theme_tip =>
      'Vous voulez économiser la batterie ? Utilisez le thème sombre AMOLED pour réduire la consommation des écrans OLED.';

  @override
  String get customize_usage_history_tip =>
      'Vous voulez conserver votre historique d\'utilisation ? Choisissez le nombre de semaines à enregistrer dans les réglages.';

  @override
  String get grouped_apps_blocking_tip =>
      'Vous voulez bloquer plusieurs applications ensemble ? Utilisez les groupes de restrictions pour partager une limite et les bloquer simultanément.';

  @override
  String get websites_blocking_tip =>
      'Vous voulez une navigation plus saine ? Bloquez des sites personnalisés ou NSFW pour rester concentré en ligne.';

  @override
  String get data_usage_tip =>
      'Vous voulez suivre votre consommation ? Surveillez les données mobiles et Wi-Fi utilisées par vos applications.';

  @override
  String get block_internet_tip =>
      'Besoin de couper Internet pour une application ? Bloquez son accès depuis son tableau de bord.';

  @override
  String get emergency_passes_tip =>
      'Besoin d\'une pause ? Utilisez jusqu\'à 3 passes d\'urgence par jour pour débloquer temporairement les applications pendant 5 minutes.';

  @override
  String get onboarding_skip_btn_label => 'Passer';

  @override
  String get onboarding_finish_setup_btn_label => 'Terminer la configuration';

  @override
  String get onboarding_page_one_title => 'Maitriser votre concentration.';

  @override
  String get onboarding_page_one_info =>
      'Que vous travailliez, étudiiez, ou que vous reposiez, Mindful met en pause les distractions et vous permet de garder le contrôle avec des sessions de concentration personnalisables.';

  @override
  String get onboarding_page_two_title => 'Bloquer les distractions.';

  @override
  String get onboarding_page_two_info =>
      'Définissez des limites d\'utilisation, mettez automatiquement en pause les applications et créez des habitudes numériques plus saines. Utilisez le mode temps de sommeil pour vous détendre et profiter d\'une nuit sans distraction.';

  @override
  String get onboarding_page_three_title => 'Confidentialité avant tout.';

  @override
  String get onboarding_page_three_info =>
      'Mindful est 100% open-source et fonctionne entièrement hors ligne. Nous ne collectons ni ne partageons pas vos données personnelles — votre vie privée est garantie à tous les niveaux.';

  @override
  String get onboarding_page_permissions_title => 'Permissions indispensables.';

  @override
  String get onboarding_page_permissions_info =>
      'Mindful a besoin des autorisations suivantes pour suivre et gérer votre temps d\'écran, vous aider à réduire les distractions et améliorer votre concentration.';

  @override
  String get dashboard_tab_title => 'Tableau de bord';

  @override
  String get focus_now_fab_button => 'Se concentrer';

  @override
  String get welcome_greetings => 'Bienvenue à nouveau,';

  @override
  String get username_snack_alert =>
      'Appuyez longuement pour modifier le nom d\'utilisateur.';

  @override
  String get username_dialog_title => 'Nom d’utilisateur';

  @override
  String get username_dialog_info =>
      'Entrez le nom d\'utilisateur qui s\'affichera sur le tableau de bord.';

  @override
  String get username_dialog_button_apply => 'Confirmer';

  @override
  String get glance_tile_title => 'Aperçu';

  @override
  String get glance_tile_subtitle =>
      'Jetez un coup d\'œil à vos statistiques d\'utilisation.';

  @override
  String get parental_controls_tile_subtitle =>
      'Mode invincible et protection anti-modification.';

  @override
  String get restrictions_heading => 'Restrictions';

  @override
  String get apps_blocking_tile_title => 'Blocage des applications';

  @override
  String get apps_blocking_tile_subtitle =>
      'Limitez vos applications de plusieurs façons.';

  @override
  String get grouped_apps_blocking_tile_title => 'Blocage groupé';

  @override
  String get grouped_apps_blocking_tile_subtitle =>
      'Limitez plusieurs groupes simultanément.';

  @override
  String get shorts_blocking_tile_subtitle =>
      'Limitez les shorts sur plusieurs plateformes.';

  @override
  String get websites_blocking_tile_subtitle =>
      'Limitez les sites pour adultes et les sites personnalisés.';

  @override
  String get screen_time_label => 'Temps d\'écran';

  @override
  String get total_data_label => 'Total d\'utilisation';

  @override
  String get mobile_data_label => 'Données mobiles';

  @override
  String get wifi_data_label => 'Données Wifi';

  @override
  String get focus_today_label => 'Se concentrer aujourd\'hui';

  @override
  String get focus_weekly_label => 'Concentration hebdomadaire';

  @override
  String get focus_monthly_label => 'Concentration mensuelle';

  @override
  String get focus_lifetime_label => 'Concentration totale';

  @override
  String get longest_streak_label => 'Plus longue série';

  @override
  String get current_streak_label => 'Série en cours';

  @override
  String get successful_sessions_label => 'Sessions réussies';

  @override
  String get failed_sessions_label => 'Sessions échouées';

  @override
  String get statistics_tab_title => 'Statistiques';

  @override
  String get screen_segment_label => 'Écran';

  @override
  String get data_segment_label => 'Données';

  @override
  String get mobile_label => 'Mobile';

  @override
  String get wifi_label => 'Wi-Fi';

  @override
  String get most_used_apps_heading => 'Applications les plus utilisées';

  @override
  String get show_all_apps_tile_title => 'Afficher toutes les apps';

  @override
  String get search_apps_hint => 'Rechercher des applications...';

  @override
  String get notifications_tab_title => 'Notifications';

  @override
  String get notifications_tab_info =>
      'Regroupez les notifications des applications et créez des horaires pour le matin, le midi, le soir ou la nuit. Restez informé sans interruptions constantes.';

  @override
  String get batched_apps_tile_title => 'Apps regroupées';

  @override
  String get batch_recap_dropdown_title => 'Type de récapitulatif';

  @override
  String get batch_recap_dropdown_info =>
      'Choisissez le contenu envoyé lorsqu\'un horaire se déclenche : toutes les notifications ou seulement un résumé.';

  @override
  String get batch_recap_option_summery_only => 'Résumé uniquement';

  @override
  String get batch_recap_option_all_notifications => 'Toutes les notifications';

  @override
  String get notification_history_tile_title => 'Historique des notifications';

  @override
  String get store_all_tile_title => 'Enregistrer toutes les notifications';

  @override
  String get store_all_tile_subtitle =>
      'Enregistrer également les notifications non regroupées.';

  @override
  String get schedules_heading => 'Horaires';

  @override
  String get new_schedule_fab_button => 'Nouvel horaire';

  @override
  String get new_schedule_dialog_info =>
      'Entrez un nom pour l\'horaire de notification pour l\'identifier facilement.';

  @override
  String get new_schedule_dialog_field_label => 'Nom de l\'horaire';

  @override
  String get bedtime_tab_title => 'Dormir';

  @override
  String get bedtime_tab_info =>
      'Fixer l\'heure du coucher en sélectionnant une période et des jours de la semaine. Choisissez les applications qui vous distraient à bloquer et activer le mode Ne pas déranger pour une nuit paisible.';

  @override
  String get schedule_tile_title => 'Planifier';

  @override
  String get schedule_tile_subtitle =>
      'Activer ou désactiver la planification quotidienne.';

  @override
  String get bedtime_no_days_selected_snack_alert =>
      'Sélectionnez au moins un jour de la semaine.';

  @override
  String get bedtime_minimum_duration_snack_alert =>
      'La durée totale du temps de sommeil doit être d\'au moins 30 min.';

  @override
  String get distracting_apps_tile_title => 'Apps qui vous distraient';

  @override
  String get distracting_apps_tile_subtitle =>
      'Sélectionnez les applications qui vous distraient de votre routine du coucher.';

  @override
  String get bedtime_distracting_apps_modify_snack_alert =>
      'La liste des applications distrayantes ne peut pas être modifiée lorsque l\'horaire de coucher est actif.';

  @override
  String get parental_controls_tab_title => 'Contrôle';

  @override
  String get invincible_mode_heading => 'Mode invincible';

  @override
  String get invincible_mode_tile_title => 'Activer le mode invincible';

  @override
  String get invincible_mode_info =>
      'Lorsque le mode invincible est actif, vous ne pouvez plus modifier les limites sélectionnées après avoir atteint votre quota quotidien. Les changements restent possibles pendant la fenêtre de modification de 10 minutes choisie.';

  @override
  String get invincible_mode_snack_alert =>
      'En raison du mode invincible, les modifications des restrictions ne sont pas autorisées.';

  @override
  String get invincible_mode_dialog_info =>
      'Êtes-vous absolument sûr de vouloir activer le Mode Invincible ? Cette action est irréversible. Une fois que le Mode Invincible est activé, vous ne pouvez pas le désactiver tant que cette application est installée sur votre appareil.';

  @override
  String get invincible_mode_turn_off_snack_alert =>
      'Le mode invincible ne peut pas être désactivé tant que cette application reste installée sur votre appareil.';

  @override
  String get invincible_mode_dialog_button_start_anyway =>
      'Démarrer quand même';

  @override
  String get invincible_mode_include_timer_tile_title => 'Inclure le minuteur';

  @override
  String get invincible_mode_include_launch_limit_tile_title =>
      'Inclure la limite de lancement';

  @override
  String get invincible_mode_include_active_period_tile_title =>
      'Inclure la période active';

  @override
  String get invincible_mode_app_restrictions_tile_title =>
      'Restrictions d\'applications';

  @override
  String get invincible_mode_app_restrictions_tile_subtitle =>
      'Empêcher toute modification des restrictions de l\'application sélectionnée une fois les limites quotidiennes dépassées.';

  @override
  String get invincible_mode_group_restrictions_tile_title =>
      'Restrictions groupées';

  @override
  String get invincible_mode_group_restrictions_tile_subtitle =>
      'Empêcher toute modification des restrictions de du groupe d\'applications sélectionné une fois les limites quotidiennes dépassées.';

  @override
  String get invincible_mode_include_shorts_timer_tile_title =>
      'Inclure les temps de shorts';

  @override
  String get invincible_mode_include_shorts_timer_tile_subtitle =>
      'Empêcher toute modification une fois votre limite quotidienne de shorts dépassée.';

  @override
  String get invincible_mode_include_bedtime_tile_title =>
      'Inclure le temps de sommeil';

  @override
  String get invincible_mode_include_bedtime_tile_subtitle =>
      'Empêche les modifications lorsque l\'horaire de coucher est actif.';

  @override
  String get protected_access_tile_title => 'Accès protégé';

  @override
  String get protected_access_tile_subtitle =>
      'Protéger Mindful avec le verrouillage de votre appareil.';

  @override
  String get protected_access_no_lock_snack_alert =>
      'Configurez d\'abord un verrouillage biométrique sur votre appareil pour activer cette fonction.';

  @override
  String get protected_access_removed_lock_snack_alert =>
      'Le verrouillage de votre appareil a été supprimé. Configurez-en un nouveau pour continuer.';

  @override
  String get protected_access_failed_lock_snack_alert =>
      'Échec de l\'authentification. Vous devez confirmer le verrouillage de votre appareil pour continuer.';

  @override
  String get tamper_protection_tile_title => 'Protection anti-modification';

  @override
  String get tamper_protection_tile_subtitle =>
      'Empêcher la désinstallation et l\'arrêt forcé de l\'application.';

  @override
  String get tamper_protection_confirmation_dialog_info =>
      'Une fois activée, cette protection empêchera la désinstallation, l\'arrêt forcé et l\'effacement des données de Mindful, sauf pendant la fenêtre de désinstallation choisie. Il n\'existe aucun autre moyen de la contourner.\n\nContinuez à vos propres risques.';

  @override
  String get uninstall_window_tile_title => 'Fenêtre de désinstallation';

  @override
  String get uninstall_window_tile_subtitle =>
      'Plage horaire quotidienne pendant laquelle vous pouvez désinstaller Mindful et modifier le mode invincible ou les restrictions.';

  @override
  String get invincible_window_tile_title => 'Fenêtre du mode invincible';

  @override
  String get invincible_window_tile_subtitle =>
      'Les limites sélectionnées peuvent être modifiées pendant les 10 minutes suivant l\'heure choisie.';

  @override
  String get shorts_blocking_tab_title => 'Blocage des shorts';

  @override
  String get shorts_blocking_tab_info =>
      'Contrôlez le temps passé sur les shorts d\'Instagram, YouTube, Snapchat, Facebook et leurs sites web.';

  @override
  String get short_content_heading => 'Contenu court';

  @override
  String shorts_time_left_from(String timeShortString) {
    return 'Temps restant sur $timeShortString';
  }

  @override
  String get short_content_timer_picker_dialog_info =>
      'Définissez une limite quotidienne pour les shorts. Une fois la limite atteinte, ils seront bloqués jusqu\'à minuit.';

  @override
  String get dating_blocking_tab_title => 'Blocage dating apps';

  @override
  String get dating_blocking_dashboard_subtitle =>
      'Limitez votre temps quotidien sur les app de rencontre';

  @override
  String get dating_blocking_tab_info =>
      'Lorsque votre temps quotidien sur une application de rencontre est écoulé, ses pages de découverte, profils en vedette, likes reçus, carte et modification du profil sont bloquées jusqu\'à la prochaine réinitialisation quotidienne.';

  @override
  String get dating_apps_heading => 'Applications de rencontre';

  @override
  String dating_daily_limit(String timeShortString) {
    return '$timeShortString par jour';
  }

  @override
  String dating_time_left_from(String timeShortString) {
    return 'Temps restant sur $timeShortString';
  }

  @override
  String get dating_timer_picker_dialog_info =>
      'Choisissez la limite quotidienne de cette application à la minute près. Les pages suivies seront bloquées lorsque le temps sera écoulé.';

  @override
  String get dating_reset_heading => 'Réinitialisation quotidienne';

  @override
  String get dating_reset_time_tile_title => 'Heure de réinitialisation';

  @override
  String get dating_reset_time_tile_subtitle =>
      'Tous les compteurs Dating redémarrent à cette heure chaque jour.';

  @override
  String get dating_reset_time_picker_info =>
      'Choisissez l\'heure de réinitialisation quotidienne de tous les compteurs Dating';

  @override
  String get instagram_features_tile_title => 'Instagram';

  @override
  String get instagram_features_tile_subtitle =>
      'Limiter des fonctionnalités sur Instagram.';

  @override
  String get instagram_features_block_reels => 'Limiter la section Reels.';

  @override
  String get instagram_features_block_explore => 'Limiter la section Explorer.';

  @override
  String get snapchat_features_tile_title => 'Snapchat';

  @override
  String get snapchat_features_tile_subtitle =>
      'Limiter des fonctionnalités sur Snapchat.';

  @override
  String get snapchat_features_block_spotlight =>
      'Limiter la section Spotlight.';

  @override
  String get snapchat_features_block_discover =>
      'Limiter la section Découvrir.';

  @override
  String get youtube_features_tile_title => 'YouTube';

  @override
  String get youtube_features_tile_subtitle =>
      'Limiter les Shorts sur YouTube.';

  @override
  String get facebook_features_tile_title => 'Facebook';

  @override
  String get facebook_features_tile_subtitle =>
      'Limiter les Reels sur Facebook.';

  @override
  String get reddit_features_tile_title => 'Reddit';

  @override
  String get reddit_features_tile_subtitle =>
      'Limiter les vidéos courtes sur Reddit.';

  @override
  String get websites_blocking_tab_title => 'Blocage des sites';

  @override
  String get websites_blocking_tab_info =>
      'Bloquez les sites pour adultes et les sites de votre choix afin de rendre votre navigation plus sûre et plus propice à la concentration.';

  @override
  String get adult_content_heading => 'Contenu pour adultes';

  @override
  String get block_nsfw_title => 'Bloquer le NSFW';

  @override
  String get block_nsfw_subtitle =>
      'Empêcher les navigateurs d\'ouvrir des sites pour adultes et pornographiques.';

  @override
  String get block_nsfw_dialog_info =>
      'Êtes-vous sûr(e) ? Cette action est irréversible. Une fois que le bloqueur de sites pour adultes est activé, vous ne pouvez pas le désactiver tant que cette application est installée sur votre appareil.';

  @override
  String get block_nsfw_dialog_button_block_anyway => 'Bloquer quand même';

  @override
  String get blocked_websites_heading => 'Sites web bloqués';

  @override
  String get blocked_websites_empty_list_hint =>
      'Appuyez sur le bouton + Ajouter un site web pour ajouter les sites distrayants que vous souhaitez bloquer.';

  @override
  String get add_website_fab_button => 'Ajouter un site web';

  @override
  String get add_website_dialog_title => 'Sites web qui vous distraient';

  @override
  String get add_website_dialog_info =>
      'Entrez l\'Url d\'un site web que vous voulez bloquer.';

  @override
  String get add_website_dialog_is_nsfw => 'S\'agit-il d\'un site NSFW ?';

  @override
  String get add_website_dialog_nsfw_warning =>
      'Attention : les sites NSFW ne peuvent plus être supprimés après leur ajout.';

  @override
  String get add_website_dialog_button_block => 'Bloquer';

  @override
  String get add_website_already_exist_snack_alert =>
      'L\'URL a déjà été ajouté à la liste des sites web bloqués.';

  @override
  String get add_website_invalid_url_snack_alert =>
      'URL invalide ! Impossible d\'analyser le nom d\'hôte.';

  @override
  String get remove_website_dialog_title => 'Retirer le site web';

  @override
  String remove_website_dialog_info(String websitehost) {
    return 'Êtes-vous sûr(e) ? Vous voulez supprimer \'$websitehost\' des sites web bloqués.';
  }

  @override
  String get focus_tab_title => 'Se concentrer';

  @override
  String get focus_tab_info =>
      'Lorsque vous avez besoin de temps pour vous concentrer, démarrez une nouvelle session en sélectionnant le type, en choisissant les applications à mettre en pause, et en activant le mode Ne pas déranger pour une concentration ininterrompue.';

  @override
  String get active_session_card_title => 'Session active';

  @override
  String get active_session_card_info =>
      'Vous avez une session de concentration active en cours ! Cliquez sur \'Voir\' pour vérifier votre progression et voir combien de temps s\'est écoulé.';

  @override
  String get active_session_card_view_button => 'Voir';

  @override
  String get focus_distracting_apps_removal_snack_alert =>
      'La suppression d\'applications de la liste des applications qui vous distraient n\'est pas autorisée tant qu\'une session de concentration est active. Cependant, vous pouvez toujours ajouter des applications supplémentaires à la liste pendant cette période.';

  @override
  String get focus_profile_tile_title => 'Profil de concentration';

  @override
  String get focus_session_duration_tile_title => 'Durée de la session';

  @override
  String get focus_session_duration_tile_subtitle =>
      'Infini (jusqu\'à ce que vous l\'arrêtiez)';

  @override
  String get focus_session_duration_dialog_info =>
      'Veuillez sélectionner la durée souhaitée pour cette session de concentration, en déterminant la durée pendant laquelle vous souhaitez rester concentré et sans distraction.';

  @override
  String get focus_profile_customization_tile_title =>
      'Personnalisation du profil';

  @override
  String get focus_profile_customization_tile_subtitle =>
      'Personnaliser les réglages du profil sélectionné.';

  @override
  String get focus_enforce_tile_title => 'Imposer la session';

  @override
  String get focus_enforce_tile_subtitle =>
      'Empêcher l\'arrêt d\'une session avant la fin prévue.';

  @override
  String get focus_session_start_button =>
      'Faites glisser pour démarrer la session';

  @override
  String get focus_session_minimum_apps_snack_alert =>
      'Sélectionnez au moins une application qui vous distrait pour démarrer la session de concentration';

  @override
  String get focus_session_already_active_snack_alert =>
      'Vous avez déjà une session de concentration active en cours d\'exécution. Veuillez terminer ou arrêter votre session actuelle avant d\'en commencer une nouvelle.';

  @override
  String get focus_session_type_study => 'Étude';

  @override
  String get focus_session_type_work => 'Travail';

  @override
  String get focus_session_type_exercise => 'Exercice';

  @override
  String get focus_session_type_meditation => 'Méditation';

  @override
  String get focus_session_type_creativeWriting => 'Écriture créative';

  @override
  String get focus_session_type_reading => 'Lecture';

  @override
  String get focus_session_type_programming => 'Programmation';

  @override
  String get focus_session_type_chores => 'Tâches ménagères';

  @override
  String get focus_session_type_projectPlanning => 'Planification de projet';

  @override
  String get focus_session_type_artAndDesign => 'Art et design';

  @override
  String get focus_session_type_languageLearning =>
      'Apprentissage d\'une langue';

  @override
  String get focus_session_type_musicPractice => 'Pratique musicale';

  @override
  String get focus_session_type_selfCare => 'Bien-être personnel';

  @override
  String get focus_session_type_brainstorming => 'Réflexion créative';

  @override
  String get focus_session_type_skillDevelopment =>
      'Développement de compétences';

  @override
  String get focus_session_type_research => 'Recherche';

  @override
  String get focus_session_type_networking => 'Réseautage';

  @override
  String get focus_session_type_cooking => 'Cuisine';

  @override
  String get focus_session_type_sportsTraining => 'Entraînement sportif';

  @override
  String get focus_session_type_restAndRelaxation => 'Repos et détente';

  @override
  String get focus_session_type_other => 'Autre';

  @override
  String get timeline_tab_title => 'Chronologie';

  @override
  String get focus_timeline_tab_info =>
      'Explorez votre parcours de concentration en sélectionnant une date dans le calendrier. Suivez vos progrès, revoyez vos réussites et tirez des enseignements des difficultés.';

  @override
  String selected_month_productive_time_snack_alert(String timeString) {
    return 'Votre temps productif total pour le mois sélectionné est de $timeString.';
  }

  @override
  String get selected_month_productive_days_label => 'Jours productifs';

  @override
  String selected_month_productive_days_snack_alert(num daysCount) {
    return 'Vous avez comptabilisé $daysCount jours productifs pendant le mois sélectionné.';
  }

  @override
  String get selected_day_focused_time_label => 'Temps de concentration';

  @override
  String selected_day_focused_time_snack_alert(String timeString) {
    return 'Votre temps de concentration total pour le jour sélectionné est de $timeString.';
  }

  @override
  String get calender_heading => 'Calendrier';

  @override
  String get your_sessions_heading => 'Vos sessions';

  @override
  String get your_sessions_empty_list_hint =>
      'Aucune session de concentration enregistrée pour le jour sélectionné.';

  @override
  String get focus_session_tile_timestamp_label => 'Horodatage';

  @override
  String get focus_session_tile_duration_label => 'Durée';

  @override
  String get focus_session_tile_reflection_label => 'Réflexion';

  @override
  String get focus_session_state_active => 'Active';

  @override
  String get focus_session_state_successful => 'Terminée';

  @override
  String get focus_session_state_failed => 'Arrêtée';

  @override
  String get active_session_tab_title => 'Session';

  @override
  String get active_session_none_warning =>
      'Aucune session active n\'a été trouvée. Retour à l\'écran d\'accueil.';

  @override
  String get active_session_dialog_button_keep_pushing =>
      'Continuer la session';

  @override
  String get active_session_finish_dialog_title => 'Terminer';

  @override
  String get active_session_finish_dialog_info =>
      'Terminer cette session de concentration maintenant ?';

  @override
  String get active_session_giveup_dialog_title => 'Arrêter';

  @override
  String get active_session_giveup_dialog_info =>
      'Arrêter cette session de concentration avant l\'heure prévue ?';

  @override
  String get active_session_reflection_dialog_title => 'Bilan de la session';

  @override
  String get active_session_reflection_dialog_info =>
      'Prenez un moment pour réfléchir à votre progression. Quel est votre objectif pour cette session ? Qu\'avez-vous accompli pendant cette session ?';

  @override
  String get active_session_reflection_dialog_tip =>
      'Astuce : vous pourrez toujours modifier ce bilan plus tard dans la chronologie des sessions.';

  @override
  String get active_session_giveup_snack_alert => 'Session arrêtée.';

  @override
  String get restriction_groups_tab_title => 'Groupes de restrictions';

  @override
  String get restriction_groups_tab_info =>
      'Définissez une limite de temps d\'écran commune à un groupe d\'applications. Lorsque l\'utilisation totale atteint cette limite, toutes les applications du groupe sont mises en pause.';

  @override
  String get restriction_group_time_spent_label => 'Temps passé aujourd\'hui';

  @override
  String get restriction_group_time_left_label => 'Temps restant aujourd\'hui';

  @override
  String get restriction_group_name_tile_title => 'Nom du groupe';

  @override
  String get restriction_group_name_picker_dialog_info =>
      'Entrez un nom pour le groupe de restriction afin de l\'identifier et de le gérer facilement.';

  @override
  String get restriction_group_timer_tile_title => 'Minuteur pour le groupe';

  @override
  String get restriction_group_timer_picker_dialog_info =>
      'Définissez une limite de temps quotidienne pour ce groupe. Une fois votre limite atteinte, toutes les applications de ce groupe seront suspendues jusqu\'à minuit.';

  @override
  String get restriction_group_active_period_tile_title =>
      'Période d\'activité du groupe';

  @override
  String restriction_group_period_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count périodes actives',
      one: '1 période active',
    );
    return '$_temp0';
  }

  @override
  String get active_period_add_button => 'Ajouter une période';

  @override
  String get remove_restriction_group_dialog_title => 'Supprimer groupe';

  @override
  String remove_restriction_group_dialog_info(String groupName) {
    return 'Êtes-vous sûr ? Vous voulez supprimer \'$groupName\' des groupes de restrictions.';
  }

  @override
  String get restriction_group_invalid_limits_snack_alert =>
      'Définissez une limite de temps ou une limite de période d\'activité.';

  @override
  String get notifications_empty_list_hint =>
      'Aucune notification n\'a été regroupée pour cette journée.';

  @override
  String get conversations_label => 'Conversations';

  @override
  String get last_24_hours_heading => 'Dernières 24 heures';

  @override
  String get notification_timeline_tab_info =>
      'Parcourez l\'historique de vos notifications en sélectionnant une date dans le calendrier. Découvrez quelles applications ont attiré votre attention et analysez vos habitudes numériques.';

  @override
  String get monthly_label => 'Mensuel';

  @override
  String get daily_label => 'Quotidien';

  @override
  String get search_notifications_sheet_info =>
      'Retrouvez facilement d\'anciennes notifications en recherchant dans leur titre ou leur contenu.';

  @override
  String get search_notifications_hint => 'Rechercher des notifications...';

  @override
  String get search_notifications_empty_list_hint =>
      'Aucune notification ne correspond à votre recherche.';

  @override
  String get app_info_none_warning =>
      'Impossible de trouver l\'application correspondant à ce paquet. Retour à l\'écran d\'accueil.';

  @override
  String get emergency_fab_button => 'Urgence';

  @override
  String emergency_dialog_info(num leftPassesCount) {
    return 'Cette action mettra en pause le bloqueur de l\'application pour les 5 prochaines minutes. Il vous reste $leftPassesCount délais. Après avoir utilisé tous les délais, l\'application restera bloquée jusqu\'à minuit, ou la session de concentration active se terminera.\n\nContinuer quand même ?';
  }

  @override
  String get emergency_dialog_button_use_anyway => 'Utiliser quand même';

  @override
  String get emergency_started_snack_alert =>
      'Le bloqueur d\'application est suspendu et reprendra le blocage dans 5 minutes.';

  @override
  String get emergency_already_active_snack_alert =>
      'Le bloqueur de l\'application est actuellement suspendu ou inactif. Si les notifications sont activées, vous recevrez informations concernant le temps restant.';

  @override
  String get emergency_no_pass_left_snack_alert =>
      'Vous avez utilisé tous vos délais d\'urgence. Les applications bloquées resteront bloquées jusqu\'à minuit, ou la session de concentration active se termine.';

  @override
  String get app_limit_status_not_set => 'Non défini';

  @override
  String get app_timer_tile_title => 'Minuteur de l\'application';

  @override
  String get app_timer_picker_dialog_info =>
      'Définissez une limite de temps quotidienne pour cette application. Une fois votre limite atteinte, l\'application sera suspendue jusqu\'à minuit.';

  @override
  String get usage_reminders_tile_title => 'Rappels d\'utilisation';

  @override
  String get usage_reminders_tile_subtitle =>
      'Des rappels discrets pendant l\'utilisation des applications limitées.';

  @override
  String get app_launch_limit_tile_title => 'Limite de lancements';

  @override
  String app_launch_limit_tile_subtitle(num count) {
    return 'Lancé $count fois aujourd\'hui.';
  }

  @override
  String get app_launch_limit_picker_dialog_info =>
      'Définissez combien de fois vous pouvez ouvrir cette application chaque jour. Une fois la limite atteinte, elle sera suspendue jusqu\'à minuit.';

  @override
  String get app_active_period_tile_title => 'Période d\'activité';

  @override
  String app_active_period_tile_subtitle(String startTime, String endTime) {
    return 'De $startTime à $endTime';
  }

  @override
  String get internet_access_tile_title => 'Accès internet';

  @override
  String get internet_access_tile_subtitle =>
      'Désactivez pour bloquer Internet pour l\'app.';

  @override
  String internet_access_blocked_snack_alert(String appName) {
    return 'Internet est bloqué pour $appName.';
  }

  @override
  String internet_access_unblocked_snack_alert(String appName) {
    return 'Internet est débloqué pour $appName.';
  }

  @override
  String get launch_app_tile_title => 'Ouvrir l\'application';

  @override
  String launch_app_tile_subtitle(String appName) {
    return 'Ouvrir $appName.';
  }

  @override
  String get go_to_app_settings_tile_title =>
      'Accéder aux paramètres de l\'application';

  @override
  String get go_to_app_settings_tile_subtitle =>
      'Gérer les notifications, les autorisations, le stockage et les autres paramètres de l\'application.';

  @override
  String get include_in_stats_tile_title => 'Inclure dans le temps d\'écran';

  @override
  String get include_in_stats_tile_subtitle =>
      'Désactivez cette option pour exclure l\'application du temps d\'écran total.';

  @override
  String app_excluded_from_stats_snack_alert(String appName) {
    return '$appName est exclue du temps d\'écran total.';
  }

  @override
  String app_include_to_stats_snack_alert(String appName) {
    return '$appName est incluse dans le temps d\'écran total.';
  }

  @override
  String get general_tab_title => 'Général';

  @override
  String get appearance_heading => 'Apparence';

  @override
  String get theme_mode_tile_title => 'Mode du thème';

  @override
  String get theme_mode_system_label => 'Système';

  @override
  String get theme_mode_light_label => 'Clair';

  @override
  String get theme_mode_dark_label => 'Sombre';

  @override
  String get material_color_tile_title => 'Couleur Material';

  @override
  String get amoled_dark_tile_title => 'Noir AMOLED';

  @override
  String get amoled_dark_tile_subtitle =>
      'Utiliser un noir pur pour le thème sombre.';

  @override
  String get dynamic_colors_tile_title => 'Couleurs dynamiques';

  @override
  String get dynamic_colors_tile_subtitle =>
      'Utiliser les couleurs de l\'appareil lorsqu\'elles sont disponibles.';

  @override
  String get defaults_heading => 'Valeurs par défaut';

  @override
  String get app_language_tile_title => 'Langue de l\'application';

  @override
  String get default_home_tab_tile_title => 'Onglet d\'accueil';

  @override
  String get usage_history_tile_title => 'Historique d\'utilisation';

  @override
  String get usage_history_15_days => '15 jours';

  @override
  String get usage_history_1_month => '1 mois';

  @override
  String get usage_history_3_month => '3 mois';

  @override
  String get usage_history_6_month => '6 mois';

  @override
  String get usage_history_1_year => '1 an';

  @override
  String get service_heading => 'Service';

  @override
  String get service_stopping_warning =>
      'Si Mindful s\'arrête de manière inattendue, accordez l\'autorisation Ignorer l\'optimisation de la batterie afin de maintenir son fonctionnement en arrière-plan. Si le problème persiste, ajoutez Mindful à la liste blanche.';

  @override
  String get whitelist_app_tile_title => 'Ajouter Mindful à la liste blanche';

  @override
  String get whitelist_app_tile_subtitle =>
      'Autoriser le démarrage automatique de Mindful.';

  @override
  String get whitelist_app_unsupported_snack_alert =>
      'Cet appareil ne permet pas de gérer le démarrage automatique.';

  @override
  String get database_tab_title => 'Base de données';

  @override
  String get import_db_tile_title => 'Importer la base de données';

  @override
  String get import_db_tile_subtitle =>
      'Importer la base de données depuis un fichier.';

  @override
  String get export_db_tile_title => 'Exporter la base de données';

  @override
  String get export_db_tile_subtitle =>
      'Exporter la base de données vers un fichier.';

  @override
  String get crash_logs_heading => 'Journaux d\'erreurs';

  @override
  String get crash_logs_info =>
      'Si vous rencontrez un problème, vous pouvez le signaler sur GitHub en joignant le fichier de journal. Celui-ci contient le fabricant et le modèle de l\'appareil, la version d\'Android, la version du SDK et les erreurs enregistrées afin de faciliter le diagnostic.';

  @override
  String get crash_logs_export_tile_title => 'Exporter les journaux d\'erreurs';

  @override
  String get crash_logs_export_tile_subtitle =>
      'Exporter les journaux d\'erreurs dans un fichier JSON.';

  @override
  String get crash_logs_view_tile_title => 'Afficher les journaux';

  @override
  String get crash_logs_view_tile_subtitle =>
      'Consulter les erreurs enregistrées.';

  @override
  String get crash_logs_empty_list_hint =>
      'Aucune erreur n\'a été enregistrée pour le moment.';

  @override
  String get crash_logs_clear_tile_title => 'Effacer les journaux';

  @override
  String get crash_logs_clear_tile_subtitle =>
      'Supprimer tous les journaux d\'erreurs de la base de données.';

  @override
  String get crash_logs_clear_dialog_info =>
      'Voulez-vous vraiment supprimer tous les journaux d\'erreurs de la base de données ?';

  @override
  String get crash_logs_clear_dialog_button_clear_anyway =>
      'Effacer quand même';

  @override
  String get about_tab_title => 'À propos';

  @override
  String get redirected_to_github_subtitle =>
      'Vous allez être redirigé vers GitHub.';

  @override
  String get contribute_heading => 'Contribuer';

  @override
  String get github_tile_title => 'GitHub';

  @override
  String get github_tile_subtitle => 'Consulter le code source.';

  @override
  String get report_issue_tile_title => 'Signaler un problème';

  @override
  String get suggest_idea_tile_title => 'Suggérer une idée';

  @override
  String get write_email_tile_title => 'Nous écrire par e-mail';

  @override
  String get write_email_tile_subtitle =>
      'Vous allez être redirigé vers votre application de messagerie.';

  @override
  String get privacy_policy_heading => 'Politique de confidentialité';

  @override
  String get privacy_policy_info =>
      'Mindful s\'engage à protéger votre vie privée. Nous ne collectons, ne stockons et ne transférons aucune donnée utilisateur. L\'application fonctionne entièrement hors ligne et ne nécessite aucune connexion Internet, afin que vos informations personnelles restent privées et sécurisées sur votre appareil. En tant que logiciel libre et open source, Mindful offre une transparence totale et vous laisse le contrôle de vos données.';

  @override
  String get more_details_button => 'Plus de détails';

  @override
  String get group_name_hint => 'Réseaux sociaux, divertissement, jeux, etc.';

  @override
  String get notification_schedule_name_hint => 'Matin, midi, travail, etc.';

  @override
  String get focus_reflection_hint =>
      'Écrivez votre objectif ou vos accomplissements...';

  @override
  String get tips_and_tricks_heading => 'Astuces';

  @override
  String get productivity_heading => 'Productivité';

  @override
  String get habits_tile_title => 'Habitudes';

  @override
  String get habits_tile_subtitle =>
      'Adoptez de meilleures habitudes et suivez vos progrès.';

  @override
  String get tasks_tile_title => 'Tâches';

  @override
  String get tasks_tile_subtitle =>
      'Planifiez vos prochaines tâches et activités.';

  @override
  String get notes_tile_title => 'Notes';

  @override
  String get notes_tile_subtitle =>
      'Consignez vos idées, pensées et listes de contrôle.';

  @override
  String get coming_soon_snack_alert => 'Bientôt disponible...';
}
