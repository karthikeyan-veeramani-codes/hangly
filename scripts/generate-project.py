#!/usr/bin/env python3
"""Generate a dependency-free, deterministic Xcode project. SPM owns automated tests."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def put(name, body): objects[uid(name)] = body; return uid(name)
def arr(items): return '(' + ', '.join(items) + ',)'
files = {}
for path in sorted((root / 'Sources').rglob('*.swift')):
    rel = str(path.relative_to(root))
    files[rel] = put(rel, '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+rel+'"; sourceTree = SOURCE_ROOT;}')
    put(rel+'build', '{isa = PBXBuildFile; fileRef = '+files[rel]+';}')
info = put('info', '{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Resources/Info.plist; sourceTree = SOURCE_ROOT;}')
icon = put('icon', '{isa = PBXFileReference; lastKnownFileType = image.icns; path = Resources/Tether.icns; sourceTree = SOURCE_ROOT;}')
iconbuild = put('iconbuild', '{isa = PBXBuildFile; fileRef = '+icon+';}')
appProduct = put('appProduct', '{isa = PBXFileReference; explicitFileType = wrapper.application; path = Tether.app; sourceTree = BUILT_PRODUCTS_DIR;}')
coreProduct = put('coreProduct', '{isa = PBXFileReference; explicitFileType = archive.ar; path = libTetherCore.a; sourceTree = BUILT_PRODUCTS_DIR;}')
linkCore = put('linkCore', '{isa = PBXBuildFile; fileRef = '+coreProduct+';}')
products = put('products', '{isa = PBXGroup; name = Products; children = '+arr([appProduct, coreProduct])+'; sourceTree = "<group>";}')
main = put('main', '{isa = PBXGroup; children = '+arr(list(files.values())+[info,icon,products])+'; sourceTree = "<group>";}')
def phase(name, kind, refs): return put(name, '{isa = '+kind+'; buildActionMask = 2147483647; files = '+arr(refs)+'; runOnlyForDeploymentPostprocessing = 0;}')
appSources = phase('appSources','PBXSourcesBuildPhase',[uid(p+'build') for p in files if 'TetherApp/' in p])
coreSources = phase('coreSources','PBXSourcesBuildPhase',[uid(p+'build') for p in files if 'TetherCore/' in p])
frameworks = phase('frameworks','PBXFrameworksBuildPhase',[linkCore])
resources = phase('resources','PBXResourcesBuildPhase',[iconbuild])
common = {'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','ENABLE_HARDENED_RUNTIME':'YES','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'""','GCC_WARN_UNUSED_VARIABLE':'YES','SWIFT_STRICT_CONCURRENCY':'complete'}
def configlist(name, extra):
    refs=[]
    for mode in ['Debug','Release']:
        settings = dict(common)
        settings.update({'SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if mode=='Debug' else '"-O"','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else '"dwarf-with-dsym"','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if mode=='Debug' else '""','ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO'})
        settings.update(extra)
        refs.append(put(name+mode, '{isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(k+' = '+v+';' for k,v in settings.items())+'};}'))
    return put(name+'configs','{isa = XCConfigurationList; buildConfigurations = '+arr(refs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
projectConfig = configlist('project',{})
coreConfig = configlist('core',{'PRODUCT_NAME':'TetherCore','PRODUCT_MODULE_NAME':'TetherCore','DEFINES_MODULE':'YES','SWIFT_EMIT_MODULE':'YES','SKIP_INSTALL':'YES','EXECUTABLE_PREFIX':'lib','MACH_O_TYPE':'staticlib'})
appConfig = configlist('app',{'PRODUCT_NAME':'Tether','PRODUCT_BUNDLE_IDENTIFIER':'in.tether.desktop','INFOPLIST_FILE':'Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','COMBINE_HIDPI_IMAGES':'YES','LD_RUNPATH_SEARCH_PATHS':'"$(inherited) @executable_path/../Frameworks"'})
coreTarget = put('coreTarget','{isa = PBXNativeTarget; name = TetherCore; productName = TetherCore; productReference = '+coreProduct+'; productType = "com.apple.product-type.library.static"; buildConfigurationList = '+coreConfig+'; buildPhases = '+arr([coreSources])+'; buildRules = (); dependencies = ();}')
proxy = put('proxy','{isa = PBXContainerItemProxy; containerPortal = '+uid('project')+'; proxyType = 1; remoteGlobalIDString = '+coreTarget+'; remoteInfo = TetherCore;}')
dependency = put('dependency','{isa = PBXTargetDependency; target = '+coreTarget+'; targetProxy = '+proxy+';}')
appTarget = put('appTarget','{isa = PBXNativeTarget; name = Tether; productName = Tether; productReference = '+appProduct+'; productType = "com.apple.product-type.application"; buildConfigurationList = '+appConfig+'; buildPhases = '+arr([appSources,frameworks,resources])+'; buildRules = (); dependencies = '+arr([dependency])+';}')
put('project','{isa = PBXProject; attributes = {LastUpgradeCheck = 2700; BuildIndependentTargetsInParallel = YES;}; buildConfigurationList = '+projectConfig+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([appTarget,coreTarget])+';}')
project = root/'Tether.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+uid('project')+';}\n')
schemes = project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'Tether.xcscheme').write_text('''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+appTarget+'''" BuildableName="Tether.app" BlueprintName="Tether" ReferencedContainer="container:Tether.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+appTarget+'''" BuildableName="Tether.app" BlueprintName="Tether" ReferencedContainer="container:Tether.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'''+appTarget+'''" BuildableName="Tether.app" BlueprintName="Tether" ReferencedContainer="container:Tether.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>
''')
