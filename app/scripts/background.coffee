chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    getFunction = ->
        obj = window
        for prop in request.fnname.split('.')
            obj = obj[prop]
        return obj
        
    switch request.type
        when 'call'
            fn = getFunction()
            response = fn.apply(this, request.args)
            sendResponse(response)
        when 'callWithCallback'
            fn = getFunction()
            fn.apply(this, request.args.concat(sendResponse))
        when 'getTab'
            sendResponse(sender.tab)
        when 'getSettings'
            storage.getSettings (settings) ->
                sendResponse(settings)
        when 'setSettings'
            storage.setSettings request.settings, (settings) ->
                sendResponse(settings)
    return true


chrome.runtime.onInstalled.addListener (details) ->
    
