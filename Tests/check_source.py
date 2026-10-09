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

if __name__ == '__main__': unittest.main(verbosity=2)
