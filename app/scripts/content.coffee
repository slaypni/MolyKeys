#require underscore.js hapt_mod.js

chrome.runtime.sendMessage {type: 'getSettings'}, (settings) ->
    haptListen = (cb) ->
        hapt_mod.listen cb, window, true, []

    listener = haptListen (keys, type, event) ->
        return true if type != 'keydown'

        isEditable = (element) ->
            return element.isContentEditable or element.nodeName.toLowerCase() in ['textarea', 'input', 'select']
        isActiveElementEditable = isEditable(document.activeElement)

        # not to intercept inputs that do not include modifiers
        return true if isActiveElementEditable and not keys.some (key) -> key in settings.interceptiveModifiers
        
        ret = true

        for op, binds of settings.bindings
            continue if not (binds.some (bind) -> _.isEqual keys, bind)
            insensitive = settings.insensitives[op]
            continue if insensitive? and (document.activeElement.nodeName.toLowerCase() in insensitive) or (document.activeElement.isContentEditable and 'textarea' in insensitive)
            Operation.get()[op]()
            ret = false if op not in settings.propagatables

        return ret


    class Operation
        instance = null
     
        @get: ->
            instance ?= new _Operation
     
        class _Operation
            constructor: ->
            
            scroll = (x, y) =>
                e = document.createEvent 'WheelEvent'
                e.initWebKitWheelEvent x, -y, window, 0, 0, 0, 0, false, false, false, false
                
                _scroll = =>
                    window.scrollBy x, y
                teardown = =>
                    document.activeElement.removeEventListener 'scroll', arguments.callee
                    _scroll = null
                    teardown = null
                document.activeElement.addEventListener 'scroll', teardown
                document.activeElement.dispatchEvent e

                window.setTimeout =>
                    _scroll?()
                    teardown?()
                , 0
                    


            isVisible = (e) =>
                return (e.offsetWidth > 0 or e.offsetHeight > 0) and window.getComputedStyle(e).visibility != 'hidden'
     
            scrollUp: =>
                scroll 0, -settings.scrollOffsetY
                    
            scrollDown: =>
                scroll 0, settings.scrollOffsetY

            scrollTop: =>
                scroll 0, -document.activeElement.scrollTop

            scrollBottom: =>
                scroll 0, document.activeElement.scrollHeight
                
            scrollLeft: =>
                scroll -settings.scrollOffsetX, 0
                
            scrollRight: =>
                scroll settings.scrollOffsetX, 0
                
            pageUp: =>
                scroll 0, -window.innerHeight
                
            pageDown: =>
                scroll 0, window.innerHeight
                
            blur: =>
                document.activeElement.blur()
                
            focusOnEditable: (offset = 1) =>
                inputQueries = ('input[type="' + type + '"]' for type in ['text', 'password', 'email', 'url', 'search', 'telephone', 'number', 'datetime'])
                query = inputQueries.join(',') + ', textarea, [contenteditable]:not([contenteditable="false"])'
                editables = _.filter document.querySelectorAll(query), isVisible
                if editables.length > 0
                    offset = offset % editables.length
                    index = _.indexOf(editables, document.activeElement)
                    index = if index == -1 then -offset else index
                    index = (index + editables.length + offset) % editables.length
                    editables[index].focus()

            focusOnPreviousEditable: =>
                @focusOnEditable -1

            historyBack: =>
                window.history.back()

            historyForward: =>
                window.history.forward()

            gotoParentDirectory: =>
                href = window.location.href.replace /\/$/g, ''
                i = href.lastIndexOf '/'
                window.location = href.substring 0, i if i > 0 and href[i-1] != '/'

            mark: =>
                @marked = {x: window.scrollX, y: window.scrollY}

            jumpToMark: =>
                window.scrollTo @marked.x, @marked.y if @marked?
