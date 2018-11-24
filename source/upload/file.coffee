import { normalize, join, extname } from 'path'
import { NoIndexHeader, stripHeader } from './header'
import * as Types from './types'

export UploadSource = { icon: 'fa-upload', name: 'Upload' }
export ExternalSource = { icon: 'fa-link', name: 'External' }

export ScriptSections = [
    id: 'main'
    name: 'Main'
  ,
    id: 'midi_editor'
    name: 'MIDI Editor'
  ,
    id: 'midi_inlineeditor'
    name: 'MIDI Inline Editor'
  ,
    id: 'midi_eventlisteditor'
    name: 'MIDI Event List Editor'
  ,
    id: 'mediaexplorer'
    name: 'Media Explorer'
]

isIndexable = (ext) ->
  for _, type of Types
    return true if type.extensions.indexOf(ext) > -1
  false

export default class File
  constructor: (@storageName, @package, @isPackage = false) ->
    @source = UploadSource
    @type = null
    @installName = ''
    @url = ''
    @platform = ''
    @install = @canInstall()
    @sections = []
    @sections.push @defaultSection() if @isPackage
    @_content = ''

  setSource: (source) ->
    if source == ExternalSource
      unless @installName
        @installName = @storageName
        @storageName = ''

      @install = @canInstall()
    else if !@storageName
      @storageName = @installName
      @installName = ''

    @source = source

  category: ->
    @package.category || 'Category'

  storageDirectory: ->
    segments = [@category()]
    segments.push @defaultName(false) unless @isPackage
    join segments...

  installDirectory: ->
    if @effectiveType().longPath then @storageDirectory() else ''

  authorSlug: ->
    @package.author.toLowerCase().replace /[^\w]+/g, ''

  defaultName: (ext = true) ->
    author = @authorSlug() || 'author'
    pkgName = @package.name || 'Package name'
    defaultExt = @package.type.extensions[0]

    "#{author}_#{pkgName}#{if ext then defaultExt else ''}"

  effectiveStorageName: ->
    @storageName || (@defaultName() if @isPackage) if @source == UploadSource

  effectiveInstallName: ->
    @installName || @effectiveStorageName()

  effectiveExtname: ->
    extname(@effectiveInstallName()).toLowerCase()

  effectiveType: ->
    @type || @package.type

  installPath: ->
    root = @effectiveType().installRoot
    filePath = join @installDirectory(), @effectiveInstallName()

    join root, normalize(filePath)

  canInstall: ->
    !@isPackage || !@effectiveType().metapackage

  defaultSection: ->
    ScriptSections[switch @category()
      when 'MIDI Editor'
        1
      else
        0
    ]

  isDefaultSection: ->
    @sections.length == 1 && @sections[0] == @defaultSection()

  options: ->
    opts = []
    opts.push @type.type if @type
    opts.push @platform if @platform

    if @effectiveType().actionList
      if @sections.length == 0
        opts.push 'nomain'
      else if @isDefaultSection()
        opts.push 'main' unless @package
      else
        sections = (section.id for section in @sections)
        opts.push "main=#{sections.join ','}"

    opts

  providesLine: ->
    opts = @options()
    line = ''
    line += "[#{opts.join(' ')}] " if opts.length > 0
    line += switch @source
      when UploadSource
        if @isPackage then '.' else @effectiveStorageName()
      when ExternalSource
        @url
      else
        'other file'
    line += " > #{@installName}" if @installName
    line

  header: ->
    filetype = @effectiveExtname()

    header = if @isPackage
      @package.header()
    else if isIndexable(filetype)
      NoIndexHeader

    header?.toString filetype

  content: ->
    @header() + "\n\n" + @_content

  setContent: (content) ->
    @_content = content
