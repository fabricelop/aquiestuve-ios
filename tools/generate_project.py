"""Deterministic, standard Xcode .pbxproj writer, with no third-party dependencies."""
from pathlib import Path
from hashlib import sha1

root = Path(__file__).resolve().parent.parent
source_files = sorted(p.name for p in (root / 'Source').glob('*.swift'))
if not source_files:
    raise SystemExit('No Swift sources found')


def oid(string):
    return sha1(('AquiEstuve:' + string).encode()).hexdigest().upper()[:24]

PROJECT = oid('project')
ROOT = oid('group-root')
SRC = oid('group-src')
PRODUCTS = oid('group-products')
SOURCES = oid('phase-sources')
RESOURCES = oid('phase-resources')
TARGET = '111111111111111111111111'
APP = oid('product-app')
PRJLIST = oid('proj-configuration-list')
TRGLIST = oid('target-configuration-list')
DBGP = oid('proj-debug')
RELP = oid('proj-release')
DBGT = oid('target-debug')
RELT = oid('target-release')

file_entries = '\n'.join(f'        {oid("file-" + name)} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};' for name in source_files)
build_entries = '\n'.join(f'        {oid("build-" + name)} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {oid("file-" + name)} /* {name} */; }};' for name in source_files)
src_children = '\n'.join(f'                {oid("file-" + name)} /* {name} */,' for name in source_files)
src_builds = '\n'.join(f'                {oid("build-" + name)} /* {name} in Sources */,' for name in source_files)

project = f'''// !$*UTF8*$!
{{
    archiveVersion = 1;
    classes = {{}};
    objectVersion = 60;
    objects = {{
/* Begin PBXBuildFile section */
{build_entries}
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
{file_entries}
        {APP} /* AquiEstuve.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AquiEstuve.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */
/* Begin PBXGroup section */
        {ROOT} = {{isa = PBXGroup; children = ({SRC}, {PRODUCTS},); sourceTree = "<group>"; }};
        {SRC} = {{isa = PBXGroup; children = (
{src_children}
        ); path = Source; sourceTree = "<group>"; }};
        {PRODUCTS} = {{isa = PBXGroup; children = ({APP},); name = Products; sourceTree = "<group>"; }};
/* End PBXGroup section */
/* Begin PBXNativeTarget section */
        {TARGET} = {{isa = PBXNativeTarget; buildConfigurationList = {TRGLIST}; buildPhases = ({SOURCES}, {RESOURCES},); buildRules = (); dependencies = (); name = AquiEstuve; productName = AquiEstuve; productReference = {APP}; productType = "com.apple.product-type.application"; }};
/* End PBXNativeTarget section */
/* Begin PBXProject section */
        {PROJECT} = {{isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; TargetAttributes = {{{TARGET} = {{CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {PRJLIST}; compatibilityVersion = "Xcode 15.0"; developmentRegion = es; hasScannedForEncodings = 0; knownRegions = (es, en, Base,); mainGroup = {ROOT}; productRefGroup = {PRODUCTS}; projectDirPath = ""; projectRoot = ""; targets = ({TARGET},); }};
/* End PBXProject section */
/* Begin PBXResourcesBuildPhase section */
        {RESOURCES} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXResourcesBuildPhase section */
/* Begin PBXSourcesBuildPhase section */
        {SOURCES} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (
{src_builds}
        ); runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXSourcesBuildPhase section */
/* Begin XCBuildConfiguration section */
        {DBGP} = {{isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; }}; name = Debug; }};
        {RELP} = {{isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; SWIFT_COMPILATION_MODE = wholemodule; }}; name = Release; }};
        {DBGT} = {{isa = XCBuildConfiguration; buildSettings = {{ ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 10; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Source/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 0.10; PRODUCT_BUNDLE_IDENTIFIER = com.aquiestuve.ios; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = minimal; TARGETED_DEVICE_FAMILY = 1; }}; name = Debug; }};
        {RELT} = {{isa = XCBuildConfiguration; buildSettings = {{ ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 10; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = Source/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 0.10; PRODUCT_BUNDLE_IDENTIFIER = com.aquiestuve.ios; PRODUCT_NAME = "$(TARGET_NAME)"; SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = minimal; TARGETED_DEVICE_FAMILY = 1; }}; name = Release; }};
/* End XCBuildConfiguration section */
/* Begin XCConfigurationList section */
        {PRJLIST} = {{isa = XCConfigurationList; buildConfigurations = ({DBGP}, {RELP},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
        {TRGLIST} = {{isa = XCConfigurationList; buildConfigurations = ({DBGT}, {RELT},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
/* End XCConfigurationList section */
    }};
    rootObject = {PROJECT};
}}
'''
output = root / 'AquiEstuve.xcodeproj' / 'project.pbxproj'
output.write_text(project, encoding='utf-8')
print(f'Generated {output.relative_to(root)}, {len(source_files)} Swift files')
