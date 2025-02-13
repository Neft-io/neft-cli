const fs = require('fs-extra')
const cp = require('child_process')
const path = require('path')
const yaml = require('js-yaml')
const Mustache = require('mustache')
const { util, logger } = require('@neft/core')
const { realpath, outputDir } = require('../../config')

const runtime = path.dirname(require.resolve('@neft/runtime-android'))

const nativeDir = './native/android'
const nativeDirOut = 'app/src/main/java/io/neft/customapp'

const iconsDir = path.join(outputDir, 'icon/android')
const iconsDirOut = 'app/src/main/res'

const manifestAppDir = './manifest/android/app'
const manifestAppDirOut = 'app'

const staticDirs = [path.join(realpath, 'static'), path.join(outputDir, 'static')]
const staticDirOut = 'app/src/main/assets/static'

const extensionsDirOut = 'app/src/main/java/io/neft/extensions'

const mainActivity = 'app/src/main/java/__MainActivity__.java'
const mainActivityDirOut = 'app/src/main/java/'

const getAndroidExtensions = async (extensions) => {
  const promises = extensions.map(async ({ shortName, dirPath }) => {
    const nativeDirPath = path.join(dirPath, 'native/android')
    if (!(await fs.exists(nativeDirPath))) return null
    let name = util.kebabToCamel(shortName)
    name = util.capitalize(name)
    const packageName = `${name.toLowerCase()}_extension`
    return {
      dirPath, nativeDirPath, name, packageName,
    }
  })
  return (await Promise.all(promises))
    .filter(result => result != null)
}

const copyRuntime = async (output) => {
  const mustacheFiles = []
  await fs.copy(runtime, output, {
    filter(source, destination) {
      if (path.extname(source) === '.mustache') {
        mustacheFiles.push({ source, destination })
        return false
      }
      return true
    },
  })
  return { mustacheFiles }
}

const copyIfExists = async (input, output) => {
  if (!(await fs.exists(input))) return
  await fs.copy(input, output)
}

const copyNativeDir = output => copyIfExists(nativeDir, path.join(output, nativeDirOut))

const copyIcons = output => copyIfExists(iconsDir, path.join(output, iconsDirOut))

const copyManifestApp = output => copyIfExists(manifestAppDir, path.join(output, manifestAppDirOut))

const copyStaticFiles = async (output) => {
  // statics are saved into one folder so needs to be copied synchronously
  // in other case we will get EEXIST exception from fs-extra
  // eslint-disable-next-line no-restricted-syntax
  for (const dir of staticDirs) {
    // eslint-disable-next-line no-await-in-loop
    await copyIfExists(dir, path.join(output, staticDirOut))
  }
}

const copyExtensions = async (output, extensions) => {
  await Promise.all(extensions.map(async ({ nativeDirPath, packageName }) => {
    await fs.copy(nativeDirPath, path.join(output, extensionsDirOut, packageName))
  }))
}

const assignManifest = (target, source) => {
  // project.dependencies
  if (source.project && Array.isArray(source.project.dependencies)) {
    target.project = target.project || {}
    target.project.dependencies = target.project.dependencies || []
    target.project.dependencies.push(...source.project.dependencies)
  }

  // project.dependencies
  if (source.project && source.project.buildscript && Array.isArray(source.project.buildscript.repositories)) {
    target.project = target.project || {}
    target.project.buildscript = target.project.buildscript || {}
    target.project.buildscript.repositories = target.project.buildscript.repositories || []
    target.project.buildscript.repositories.push(...source.project.buildscript.repositories)
  }

  // project.dependencies
  if (source.project && source.project.allprojects && Array.isArray(source.project.allprojects.repositories)) {
    target.project = target.project || {}
    target.project.allprojects = target.project.allprojects || {}
    target.project.allprojects.repositories = target.project.allprojects.repositories || []
    target.project.allprojects.repositories.push(...source.project.allprojects.repositories)
  }

  // app.dependencies
  if (source.app && Array.isArray(source.app.dependencies)) {
    target.app = target.app || {}
    target.app.dependencies = target.app.dependencies || []
    target.app.dependencies.push(...source.app.dependencies)
  }

  // app.plugins
  if (source.app && Array.isArray(source.app.plugins)) {
    target.app = target.app || {}
    target.app.plugins = target.app.plugins || []
    target.app.plugins.push(...source.app.plugins)
  }

  // activityXmlManifest
  if (source.activityXmlManifest) {
    target.activityXmlManifest = target.activityXmlManifest || ''
    target.activityXmlManifest += `${source.activityXmlManifest}\n`
  }

  // applicationXmlManifest
  if (source.applicationXmlManifest) {
    target.applicationXmlManifest = target.applicationXmlManifest || ''
    target.applicationXmlManifest += `${source.applicationXmlManifest}\n`
  }

  // xmlManifest
  if (source.xmlManifest) {
    target.xmlManifest = target.xmlManifest || ''
    target.xmlManifest += `${source.xmlManifest}\n`
  }
}

const assignExtenionManifests = async (manifest, extensions) => {
  await Promise.all(extensions.map(async ({ dirPath }) => {
    const manifestPath = path.join(dirPath, 'manifest/android.yaml')
    try {
      assignManifest(manifest, yaml.safeLoad(await fs.readFile(manifestPath, 'utf-8')))
    } catch (error) {
      // NOP
    }
  }))
}

const processMustacheFile = async ({ source, destination }, config) => {
  const file = await fs.readFile(source, 'utf-8')
  const properDestination = destination.slice(0, -'.mustache'.length)
  const properFile = Mustache.render(file, config)
  await fs.writeFile(properDestination, properFile)
}

const processMustacheFiles = (files, config) => {
  const promises = files.map(file => processMustacheFile(file, config))
  return Promise.all(promises)
}

const prepareMainActivity = async (manifest, output) => {
  const packagePath = manifest.package.replace(/\./g, '/')
  const source = path.join(output, mainActivity)
  const destination = path.join(output, mainActivityDirOut, packagePath, 'MainActivity.java')
  await fs.move(source, destination)
}

const assembleApk = (production, output) => new Promise((resolve, reject) => {
  const gradleMode = production ? 'assembleRelease' : 'assembleDebug'
  let cmd
  if (process.platform.startsWith('win')) {
    cmd = `./gradlew.bat ${gradleMode} --quiet`
  } else {
    cmd = `chmod +x gradlew && ./gradlew ${gradleMode} --quiet`
  }
  const gradleProcess = cp.exec(cmd, { cwd: output }, (error) => {
    if (error) reject(error)
    else resolve()
  })
  gradleProcess.stdout.pipe(process.stdout)
})

exports.build = async ({
  manifest, output, filepath, extensions, production,
}) => {
  if (!process.env.ANDROID_HOME) {
    throw new Error('ANDROID_HOME environment variable need to be set to the Android SDK location')
  }

  logger.log('   Copying runtime files')

  const bundle = await fs.readFile(filepath, 'utf-8')
  const androidExtensions = await getAndroidExtensions(extensions)

  await fs.emptyDir(output)
  const { mustacheFiles } = await copyRuntime(output)

  await Promise.all([
    copyNativeDir(output), copyIcons(output), copyManifestApp(output),
    copyStaticFiles(output), copyExtensions(output, androidExtensions),
    assignExtenionManifests(manifest, androidExtensions),
  ])

  await processMustacheFiles(mustacheFiles, {
    bundle,
    manifest,
    extensions: androidExtensions,
  })

  await prepareMainActivity(manifest, output)

  logger.log('   Building Android APK')
  logger.log('\n------------------')
  await assembleApk(production, output)
  logger.log('------------------\n')
}
