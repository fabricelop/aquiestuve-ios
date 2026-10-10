"""Deterministic, standard Xcode .pbxproj writer, with no third-party dependencies."""
from pathlib import Path
from hashlib import sha1
import sys


root = Path(__file__).resolve().parent.parent
include_live = '--no-live' not in sys.argv
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

if include_live:
    ext_target = oid('widget-target')
    ext_product = oid('widget-product')
    ext_group = oid('widget-group')
    ext_file = oid('widget-file')
    ext_info = oid('widget-info')
    ext_file_build = oid('widget-file-build')
    ext_attr_build = oid('widget-attributes-build')
    ext_embed_build = oid('widget-embed-build')
    ext_src_phase = oid('widget-sources')
    ext_copy_phase = oid('embed-widget')
    ext_config_list = oid('widget-configurations')
    ext_debug = oid('widget-debug')
    ext_release = oid('widget-release')
    ext_proxy = oid('widget-proxy')
    ext_dependency = oid('widget-dependency')
    widget_code = f'''        {ext_file_build} /* LivePlacesWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ext_file} /* LivePlacesWidget.swift */; }};
        {ext_attr_build} /* LivePlaceAttributes.swift in Widget Sources */ = {{isa = PBXBuildFile; fileRef = {oid('file-LivePlaceAttributes.swift')} /* LivePlaceAttributes.swift */; }};
        {ext_embed_build} /* AquiEstuveLiveWidget.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {ext_product} /* AquiEstuveLiveWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy,);}}; }};
'''
    project = project.replace('/* End PBXBuildFile section */', widget_code + '/* End PBXBuildFile section */')
    widget_code = f'''        {ext_file} /* LivePlacesWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LivePlacesWidget.swift; sourceTree = "<group>"; }};
        {ext_info} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
        {ext_product} /* AquiEstuveLiveWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = AquiEstuveLiveWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
'''
    project = project.replace('/* End PBXFileReference section */', widget_code+'/* End PBXFileReference section */')
    project = project.replace(f'children = ({{SRC}}, {{PRODUCTS}},);', f'children = ({{SRC}}, {ext_group}, {{PRODUCTS}},);')
    # previous replacement above uses literal braces; use actual concrete replacement too.
    project = project.replace(f'children = ({SRC}, {PRODUCTS},);', f'children = ({SRC}, {ext_group}, {PRODUCTS},);')
    project = project.replace(f'children = ({APP},);', f'children = ({APP}, {ext_product},);')
    widget_code=f'''        {ext_group} /* LiveWidget */ = {{isa = PBXGroup; children = ({ext_file}, {ext_info},); path = LiveWidget; sourceTree = "<group>"; }};
'''
    project=project.replace('/* End PBXGroup section */', widget_code+'/* End PBXGroup section */')
    project=project.replace(f'buildPhases = ({SOURCES}, {RESOURCES},); buildRules = (); dependencies = ();',
                            f'buildPhases = ({SOURCES}, {RESOURCES}, {ext_copy_phase},); buildRules = (); dependencies = ({ext_dependency},);')
    widget_code=f'''        {ext_target} /* AquiEstuveLiveWidget */ = {{isa = PBXNativeTarget; buildConfigurationList = {ext_config_list}; buildPhases = ({ext_src_phase},); buildRules = (); dependencies = (); name = AquiEstuveLiveWidget; productName = AquiEstuveLiveWidget; productReference = {ext_product}; productType = "com.apple.product-type.app-extension"; }};
'''
    project=project.replace('/* End PBXNativeTarget section */',widget_code+'/* End PBXNativeTarget section */')
    project=project.replace(f'targets = ({TARGET},);', f'targets = ({TARGET}, {ext_target},);')
    widget_code=f'''/* Begin PBXCopyFilesBuildPhase section */
        {ext_copy_phase} /* Embed App Extensions */ = {{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({ext_embed_build},); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; }};
/* End PBXCopyFilesBuildPhase section */
/* Begin PBXContainerItemProxy section */
        {ext_proxy} = {{isa = PBXContainerItemProxy; containerPortal = {PROJECT}; proxyType = 1; remoteGlobalIDString = {ext_target}; remoteInfo = AquiEstuveLiveWidget; }};
/* End PBXContainerItemProxy section */
/* Begin PBXTargetDependency section */
        {ext_dependency} = {{isa = PBXTargetDependency; target = {ext_target}; targetProxy = {ext_proxy}; }};
/* End PBXTargetDependency section */
'''
    project=project.replace('/* Begin PBXResourcesBuildPhase section */',widget_code+'/* Begin PBXResourcesBuildPhase section */')
    widget_code=f'''        {ext_src_phase} /* Sources: LiveWidget */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ext_file_build}, {ext_attr_build},); runOnlyForDeploymentPostprocessing = 0; }};
'''
    project=project.replace('/* End PBXSourcesBuildPhase section */',widget_code+'/* End PBXSourcesBuildPhase section */')
    widget_code=f'''        {ext_debug} = {{isa = XCBuildConfiguration; buildSettings = {{ APPLICATION_EXTENSION_API_ONLY = YES; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 13; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = LiveWidget/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 0.13; PRODUCT_BUNDLE_IDENTIFIER = com.aquiestuve.ios.LiveWidget; PRODUCT_NAME = "$(TARGET_NAME)"; SKIP_INSTALL = YES; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; TARGETED_DEVICE_FAMILY = 1; }}; name = Debug; }};
        {ext_release} = {{isa = XCBuildConfiguration; buildSettings = {{ APPLICATION_EXTENSION_API_ONLY = YES; CODE_SIGN_STYLE = Automatic; CURRENT_PROJECT_VERSION = 13; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = LiveWidget/Info.plist; IPHONEOS_DEPLOYMENT_TARGET = 17.0; MARKETING_VERSION = 0.13; PRODUCT_BUNDLE_IDENTIFIER = com.aquiestuve.ios.LiveWidget; PRODUCT_NAME = "$(TARGET_NAME)"; SKIP_INSTALL = YES; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; }}; name = Release; }};
'''
    project=project.replace('/* End XCBuildConfiguration section */',widget_code+'/* End XCBuildConfiguration section */')
    widget_code=f'''        {ext_config_list} = {{isa = XCConfigurationList; buildConfigurations = ({ext_debug}, {ext_release},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
'''
    project=project.replace('/* End XCConfigurationList section */',widget_code+'/* End XCConfigurationList section */')
    # Target attributes avoid Xcode migration warnings and clarify extension ownership.
    project=project.replace(f'{TARGET} = {{CreatedOnToolsVersion = 16.0; }};',
                            f'{TARGET} = {{CreatedOnToolsVersion = 16.0; }}; {ext_target} = {{CreatedOnToolsVersion = 16.0; }};')
    # Change app version only, keep original bundle id unchanged for in-place upgrades.
    project=project.replace('CURRENT_PROJECT_VERSION = 10;', 'CURRENT_PROJECT_VERSION = 13;')
    project=project.replace('MARKETING_VERSION = 0.10;', 'MARKETING_VERSION = 0.13;')
else:
    project=project.replace('CURRENT_PROJECT_VERSION = 10;', 'CURRENT_PROJECT_VERSION = 13;')
    project=project.replace('MARKETING_VERSION = 0.10;', 'MARKETING_VERSION = 0.13;')

output = root / 'AquiEstuve.xcodeproj' / 'project.pbxproj'
output.write_text(project, encoding='utf-8')
print(f'Generated {output.relative_to(root)}, {len(source_files)} Swift files')
