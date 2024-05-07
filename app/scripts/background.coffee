import * as storage from './storage'

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.type
        when 'removeTab'
            chrome.tabs.remove(request.tabId)
        when 'createTab'
            response = chrome.tabs.create({})
            sendResponse(response)
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
    
