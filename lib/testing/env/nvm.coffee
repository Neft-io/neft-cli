'use strict'

childProcess = require 'child_process'
config = require '../cli/config'
pathUtils = require 'path'
which = require 'which'

{utils, log} = Neft

PROCESS_OPTIONS =
    silent: true
    env: utils.merge {}, process.env

getInitPath = (env) ->
    path = config.getPlatformOutFolder 'node'
    pathUtils.join path, 'build/app-node-develop.js'

exports.getName = (env) ->
    "Node v#{env.version} tests"

exports.execCommand = (nodeVersion, command, logsReader, callback) ->
    mainErr = null
    prefix = ". $NVM_DIR/nvm.sh && nvm exec #{nodeVersion} "
    command = "#{prefix} #{command}"
    PROCESS_OPTIONS.env.NODE_CP_EXEC_PREFIX = prefix
    nvmProcess = childProcess.exec command, PROCESS_OPTIONS
    nvmProcess.stdout.on 'data', (data) ->
        logsReader?.log data
        if logsReader?.terminated
            nvmProcess.kill()
    nvmProcess.stderr.on 'data', (data) ->
        log.error String(data).trim()
    nvmProcess.on 'exit', ->
        unless logsReader?.terminated
            mainErr ||= "NVM tests terminated before ending"
        callback mainErr or logsReader?.error

exports.run = (env, logsReader, callback) ->
    {version} = env
    log.info "running nvm with node version #{version}"
    path = getInitPath env
    exports.execCommand version, "node #{path}", logsReader, (err) ->
        log.info 'nvm terminated'
        callback err
