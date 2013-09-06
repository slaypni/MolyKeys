# require underscore.js

INITIAL_SETTINGS =
    interceptiveModifiers: ['Ctrl', 'Alt', 'Command', 'Meta']
    scrollOffsetX: 40
    scrollOffsetY: 40
    propagatables: ['blur']
    insensitives:
        scrollUp: ['textarea']
        scrollDown: ['textarea']
        scrollTop: ['textarea']
        scrollBottom: ['textarea']
        scrollLeft: ['textarea', 'input']
        scrollRight: ['textarea', 'input']
        pageUp: ['textarea']
        pageDown: ['textarea']
        blur: []
        focusOnEditable: []
        historyBack: []
        historyForward: []
        gotoParentDirectory: []
        mark: ['textarea']
        jumpToMark: ['textarea']
    bindings:
        scrollUp: [['Ctrl', 'P']]
        scrollDown: [['Ctrl', 'N']]
        scrollTop: [['Shift', 'Alt', ',']]
        scrollBottom: [['Shift', 'Alt', '.']]
        scrollLeft: [['Ctrl', 'B']]
        scrollRight: [['Ctrl', 'F']]
        pageUp: [['Alt', 'V']]
        pageDown: [['Ctrl', 'V']]
        blur: [['Ctrl', 'G']]
        focusOnEditable: [['Ctrl', 'I']]
        historyBack: [['Ctrl', '/']]
        historyForward: [['Alt', '/']]
        gotoParentDirectory: [['Alt', 'Up']]
        mark: [['Ctrl', 'M']]
        jumpToMark: [['Ctrl', 'J']]

EMPTY_SETTINGS =
    ( (items) ->
        callee = arguments.callee
        if _.isString(items) then ''
        else if _.isNumber(items) then 0
        else if _.isArray(items) then []
        else if _.isObject(items)
            _.object([k, callee(v)] for k, v of items)
        else null
    )(INITIAL_SETTINGS)

###
@param {Function} cb
    @param {Object} settings
###
getSettings = (cb) ->
    chrome.storage.local.get null, (items) ->
        settings = {bindings: {}}
        for k, v of INITIAL_SETTINGS
            if not items.hasOwnProperty(k)
                settings[k] = v
            else if k == 'bindings'
                used = null
                setBinding = (bindings, name, binding) ->
                    used ?= _.uniq(_.flatten(_.values(items.bindings), true).map (shortcuts) -> shortcuts.join(' '))
                    bindings[name] = (shortcuts for shortcuts in binding when shortcuts.join(' ') not in used)
                    used = used.concat(bindings[name])
            
                for name, binding of v
                    if items.bindings.hasOwnProperty(name)
                        settings.bindings[name] = items.bindings[name]
                    else # if a new kind of binding is added (by update), shortcuts that is not used in previous settings can be set 
                        setBinding(settings.bindings, name, binding)
            else
                settings[k] = items[k]
        cb(settings)

###
Sanitize settings.
@param {Object} settings An object to be sanitized that has keys corresponding to settings.
@param {String} key Given this param, check a setting that has the key. Optional.
@return {Object} sanitized settings.
###
getSanitizedSettings = (settings, key = null) ->
    if not key?
        s = {}
        for k, _v of settings
            s[k] = getSanitizedSettings(settings, k)
        return s
        
    if not settings.hasOwnProperty(key) then return undefined
    val = settings[key]
    switch key
        when 'bindings'
            getSanitizedBindings(val)
        when 'scrollOffsetX'
            if isNaN parseInt val then INITIAL_SETTINGS.scrollOffsetX else parseInt val
        when 'scrollOffsetY'
            if isNaN parseInt val then INITIAL_SETTINGS.scrollOffsetY else parseInt val
        else val

getSanitizedBindings = (bindings, key = null) ->
    if not key?
        b = {}
        for k, _v of bindings
            b[k] = getSanitizedBindings(bindings, k)
        return b

    if not bindings.hasOwnProperty(key) then return undefined    
    binding = _.uniq bindings[key], false, (shortcuts) -> shortcuts.join(' ')
    for i in _.range(binding.length)
        if binding[i].length == 0
            binding.splice(i, 1)
    return binding

setSettings = (settings, cb = null) ->
    _settings = getSanitizedSettings(settings)
    chrome.storage.local.set _settings, ->
        cb?(_settings)

@storage =
    getSettings: getSettings
    setSettings: setSettings
    getSanitizedSettings: getSanitizedSettings
    getSanitizedBindings: getSanitizedBindings
