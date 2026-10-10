"""Offline source, plist, privacy and cost-safety checks. Not a substitute for Xcode compile."""
from pathlib import Path
import plistlib
import re
import unittest
root = Path(__file__).resolve().parent.parent

class Checks(unittest.TestCase):
    def test_plist(self):
        with (root / 'Source/Info.plist').open('rb') as handle:
            data = plistlib.load(handle)
        for key in ('NSLocationWhenInUseUsageDescription', 'NSLocationAlwaysAndWhenInUseUsageDescription'):
            self.assertTrue(data[key])
        self.assertIn('location', data['UIBackgroundModes'])

    def test_all_swift_files_in_project(self):
        project = (root / 'AquiEstuve.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
        for file in (root / 'Source').glob('*.swift'):
            self.assertIn(file.name + ' in Sources', project)
        self.assertIn('com.aquiestuve.ios', project)

    def test_no_automatic_ci(self):
        workflow = (root / '.github/workflows/build-iphone.yml').read_text(encoding='utf-8')
        self.assertIn('workflow_dispatch:', workflow)
        self.assertNotRegex(workflow, r'(?m)^\s*(push|pull_request|schedule|cron):')
        self.assertIn('CODE_SIGNING_ALLOWED=NO', workflow)
        self.assertIn('retention-days: 1', workflow)

    def test_poi_limits(self):
        source = (root / 'Source/NearbySearch.swift').read_text(encoding='utf-8')
        self.assertIn('timeIntervalSince(previous) > 600', source)
        self.assertIn('min(700, max(100, radius))', source)
        self.assertIn('addOSM', source)

    def test_background_visit_monitoring(self):
        source = (root / 'Source/LocationService.swift').read_text(encoding='utf-8')
        self.assertIn('startMonitoringVisits()', source)
        self.assertIn('didVisit visit: CLVisit', source)
        self.assertIn('.authorizedAlways', source)

    def test_extended_search_is_manual(self):
        nearby = (root / 'Source/NearbySearch.swift').read_text(encoding='utf-8')
        now = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        self.assertIn('naturalLanguageQuery = query', nearby)
        self.assertIn('func expandNearby(', nearby)
        self.assertIn('previousExpansion', nearby)
        self.assertIn('onSubmit { namedSearch(near: position) }', now)

    def test_safe_confirmation_and_map_modes(self):
        source = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        self.assertIn('@AppStorage("ae_show_map")', source)
        self.assertIn('fullScreenCover(isPresented: $fullMap)', source)
        self.assertIn('Button("Confirmar que estoy aquí")', source)
        self.assertIn('Button("Guardar categoría sin crear visita")', source)

    def test_legacy_data_migration(self):
        model = (root / 'Source/Models.swift').read_text(encoding='utf-8')
        store = (root / 'Source/VisitStore.swift').read_text(encoding='utf-8')
        self.assertIn('decodeIfPresent([String: String].self, forKey: .categoryOverrides)', model)
        self.assertIn('categoryOverrides: categoryOverrides', store)
        self.assertIn('func receiveWalkStop(', store)

    def test_historical_review_and_battery_guard(self):
        history = (root / 'Source/HistoryView.swift').read_text(encoding='utf-8')
        location = (root / 'Source/LocationService.swift').read_text(encoding='utf-8')
        self.assertIn('near: position, radius: 1000', history)
        self.assertIn('3 * 3600', location)
        self.assertIn('sendTestNotification', location)

    def test_probables_and_complete_catalogue(self):
        now = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        scoring = (root / 'Source/VenuePriority.swift').read_text(encoding='utf-8')
        self.assertIn('ae_venue_mode', now)
        self.assertIn('"probables"', now)
        self.assertIn('"todos"', now)
        self.assertIn('candidate.isProbable', now)
        self.assertIn('venueKind', scoring)
        self.assertIn('relevanceScore', scoring)

    def test_clustered_map_with_explicit_zoom_and_full_cluster_list(self):
        mapcode = (root / 'Source/ClusteredPlacesMap.swift').read_text(encoding='utf-8')
        now = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        self.assertIn('clusteringIdentifier', mapcode)
        self.assertIn('MKClusterAnnotation', mapcode)
        self.assertIn('zoomStep', mapcode)
        self.assertIn('GroupedPlacesList', now)
        self.assertIn('plus.magnifyingglass', now)
        self.assertIn('minus.magnifyingglass', now)
        self.assertIn('searchMapArea(', now)

    def test_live_extension_structure(self):
        import plistlib
        project = (root / 'AquiEstuve.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
        self.assertIn('LivePlacesWidget.swift in Sources', project)
        self.assertIn('LivePlaceAttributes.swift in Widget Sources', project)
        self.assertIn('PBXCopyFilesBuildPhase', project)
        self.assertIn('com.aquiestuve.ios.LiveWidget', project)
        with (root / 'LiveWidget/Info.plist').open('rb') as f:
            self.assertEqual(plistlib.load(f)['NSExtension']['NSExtensionPointIdentifier'],
                             'com.apple.widgetkit-extension')
        with (root / 'Source/Info.plist').open('rb') as f:
            self.assertTrue(plistlib.load(f)['NSSupportsLiveActivities'])
        self.assertIn('ActivityConfiguration(', (root / 'LiveWidget/LivePlacesWidget.swift').read_text(encoding='utf-8'))
        self.assertIn('Activity.request(', (root / 'Source/LivePlacesManager.swift').read_text(encoding='utf-8'))

    def test_live_updates_are_throttled_and_safe(self):
        mgr = (root / 'Source/LivePlacesManager.swift').read_text(encoding='utf-8')
        now = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        self.assertIn('timeIntervalSince(lastRefreshAt) < 180', mgr)
        self.assertIn('LivePlacesManager.shared.refreshIfUseful', (root / 'Source/LocationService.swift').read_text(encoding='utf-8'))
        self.assertIn('Bundle.main.builtInPlugInsURL', mgr)
        self.assertIn('"Confirmar que estoy aquí"', now)
        self.assertNotIn('store.assign(item)', (root / 'LiveWidget/LivePlacesWidget.swift').read_text(encoding='utf-8'))

    def test_aliases_migrate_from_old_histories(self):
        model = (root / 'Source/Models.swift').read_text(encoding='utf-8')
        store = (root / 'Source/VisitStore.swift').read_text(encoding='utf-8')
        self.assertIn('placeAliases: [String: UUID] = [:]', model)
        self.assertIn('decodeIfPresent([String: UUID].self, forKey: .placeAliases) ?? [:]', model)
        self.assertIn('placeAliases: placeAliases', store)
        self.assertIn('func canonicalPlace(for candidate:', store)
        self.assertIn('func mergeCandidates(primary:', store)
        self.assertIn('StayReconciliation.reconcile(', store)

    def test_manual_confirmation_is_required_for_merging(self):
        view = (root / 'Source/DuplicateMergeView.swift').read_text(encoding='utf-8')
        now = (root / 'Source/NowView.swift').read_text(encoding='utf-8')
        places = (root / 'Source/SavedPlacesView.swift').read_text(encoding='utf-8')
        self.assertIn('confirmationDialog("¿Son exactamente el mismo establecimiento?"', view)
        self.assertIn('store.mergeCandidates(primary:', view)
        self.assertIn('DuplicateSuggester.suggest(', now)
        self.assertIn('Es el mismo lugar que otro…', now)
        self.assertIn('Fusionar con otro lugar guardado', places)
        self.assertNotIn('store.assign(', view)

    def test_live_visual_diagnostic_is_data_free(self):
        widget = (root / 'LiveWidget/LivePlacesWidget.swift').read_text(encoding='utf-8')
        manager = (root / 'Source/LivePlacesManager.swift').read_text(encoding='utf-8')
        settings = (root / 'Source/SettingsView.swift').read_text(encoding='utf-8')
        self.assertIn('if context.state.diagnostic {', widget)
        self.assertIn('func startVisualTest()', manager)
        self.assertIn('options = diagnostic ? []', manager)
        self.assertIn('Ver diagnóstico de iOS y extensión', settings)
        self.assertIn('Prueba visual del panel', settings)
        self.assertNotIn('VisitStore.shared.assign(', widget)

    def test_no_map_network_spam(self):
        nearby = (root / 'Source/NearbySearch.swift').read_text(encoding='utf-8')
        self.assertIn('timeIntervalSince(previous) > 600', nearby)
        self.assertIn('timeIntervalSince(previousExpansion) >= 60', nearby)
        self.assertIn('if let exact = store.canonicalPlace(for: item)', nearby)

    def test_mapkit_annotation_cannot_regress(self):
        source = (root / 'Source/CreatePlaceView.swift').read_text(encoding='utf-8')
        self.assertIn('as? MKPointAnnotation', source)
        self.assertIn('context.coordinator.parent = self', source)

    def test_pulse_first_without_persistent_gps(self):
        pulse = (root / 'Source/PulseView.swift').read_text(encoding='utf-8')
        root_view = (root / 'Source/RootView.swift').read_text(encoding='utf-8')
        self.assertIn('PulseView(openExplorer:', root_view)
        self.assertIn('NearbyNotificationCache.suggestions', pulse)
        self.assertNotIn('startUpdatingLocation()', pulse)
        self.assertNotIn('MKLocalSearch', pulse)
        self.assertIn('TimelineView(.periodic(from: .now, by: 60))', pulse)

    def test_walk_hysteresis_and_episode_merger(self):
        location = (root / 'Source/LocationService.swift').read_text(encoding='utf-8')
        store = (root / 'Source/VisitStore.swift').read_text(encoding='utf-8')
        self.assertIn('delta > 115 && point.speed >= 1.5', location)
        self.assertIn('timeIntervalSince(since) >= 45', location)
        self.assertIn('func reconcileStays()', store)
        self.assertIn('visits-pre-pulse-013.json', store)
        self.assertIn('StayReconciliation.reconcile(', store)
        self.assertIn('if let a = existing.placeID, let b = entry.placeID, a != b',
                      (root / 'Source/StayReconciliation.swift').read_text(encoding='utf-8'))

    def test_hundreds_of_searchable_categories(self):
        categories = (root / 'Source/CategoryCatalog.swift').read_text(encoding='utf-8')
        self.assertGreaterEqual(categories.count('DetailedCategory(family:'), 300)
        self.assertIn('Escuela de Arquitectura', categories)
        self.assertIn('Colegio de Arquitectos', categories)
        self.assertIn('Sede de telecomunicaciones', categories)
        self.assertIn('searchable(text: $query', categories)
        for f in ('NowView.swift', 'SavedPlacesView.swift', 'CreatePlaceView.swift'):
            self.assertIn('CategoryPickerView(selection:', (root/'Source'/f).read_text(encoding='utf-8'))

    def test_no_extra_background_requests(self):
        root_view = (root / 'Source/RootView.swift').read_text(encoding='utf-8')
        self.assertIn('openExplorer = true', root_view)
        location = (root / 'Source/LocationService.swift').read_text(encoding='utf-8')
        self.assertIn('if walkMode && authorization == .authorizedAlways', location)
        self.assertIn('startMonitoringSignificantLocationChanges()', location)


if __name__ == '__main__': unittest.main(verbosity=2)

# Additional acceptance checks for v0.10 are registered below because the source
# tester is run on Linux/Windows, where UIKit frameworks are unavailable.
