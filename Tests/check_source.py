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
        project = (root / 'AquiEstuve.xcodeproj/project.pbxproj').read_text()
        for file in (root / 'Source').glob('*.swift'):
            self.assertIn(file.name + ' in Sources', project)
        self.assertIn('com.aquiestuve.ios', project)

    def test_no_automatic_ci(self):
        workflow = (root / '.github/workflows/build-iphone.yml').read_text()
        self.assertIn('workflow_dispatch:', workflow)
        self.assertNotRegex(workflow, r'(?m)^\s*(push|pull_request|schedule|cron):')
        self.assertIn('CODE_SIGNING_ALLOWED=NO', workflow)
        self.assertIn('retention-days: 1', workflow)

    def test_poi_limits(self):
        source = (root / 'Source/NearbySearch.swift').read_text()
        self.assertIn('timeIntervalSince(previous) > 600', source)
        self.assertIn('min(700, max(100, radius))', source)
        self.assertIn('addOSM', source)

    def test_background_visit_monitoring(self):
        source = (root / 'Source/LocationService.swift').read_text()
        self.assertIn('startMonitoringVisits()', source)
        self.assertIn('didVisit visit: CLVisit', source)
        self.assertIn('.authorizedAlways', source)

    def test_extended_search_is_manual(self):
        nearby = (root / 'Source/NearbySearch.swift').read_text()
        now = (root / 'Source/NowView.swift').read_text()
        self.assertIn('naturalLanguageQuery = query', nearby)
        self.assertIn('func expandNearby(', nearby)
        self.assertIn('previousExpansion', nearby)
        self.assertIn('onSubmit { namedSearch(near: position) }', now)

    def test_safe_confirmation_and_map_modes(self):
        source = (root / 'Source/NowView.swift').read_text()
        self.assertIn('@AppStorage("ae_show_map")', source)
        self.assertIn('fullScreenCover(isPresented: $fullMap)', source)
        self.assertIn('Button("Confirmar que estoy aquí")', source)
        self.assertIn('Button("Guardar categoría sin crear visita")', source)

    def test_legacy_data_migration(self):
        model = (root / 'Source/Models.swift').read_text()
        store = (root / 'Source/VisitStore.swift').read_text()
        self.assertIn('decodeIfPresent([String: String].self, forKey: .categoryOverrides)', model)
        self.assertIn('categoryOverrides: categoryOverrides', store)
        self.assertIn('func receiveWalkStop(', store)

    def test_historical_review_and_battery_guard(self):
        history = (root / 'Source/HistoryView.swift').read_text()
        location = (root / 'Source/LocationService.swift').read_text()
        self.assertIn('near: position, radius: 1000', history)
        self.assertIn('3 * 3600', location)
        self.assertIn('sendTestNotification', location)

if __name__ == '__main__': unittest.main(verbosity=2)

# Additional acceptance checks for v0.10 are registered below because the source
# tester is run on Linux/Windows, where UIKit frameworks are unavailable.
