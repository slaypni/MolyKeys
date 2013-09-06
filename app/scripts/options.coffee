CONFIG_DESCRIPTIONS = [
    {name: 'scrollOffsetX', description: 'Scroll Step Size X'}
    {name: 'scrollOffsetY', description: 'Scroll Step Size Y'}
]

BINDING_DESCRIPTIONS = [
    {name: 'scrollUp', description: 'Scroll Up'}
    {name: 'scrollDown', description: 'Scroll Down'}
    {name: 'scrollLeft', description: 'Scroll Left'}
    {name: 'scrollRight', description: 'Scroll Right'}
    {name: 'pageUp', description: 'Page Up'}
    {name: 'pageDown', description: 'Page Down'}
    {name: 'scrollTop', description: 'Scroll Top'}
    {name: 'scrollBottom', description: 'Scroll Bottom'}
    {name: 'focusOnEditable', description: 'Focus On Editables'}
    {name: 'blur', description: 'Focus Out'}
    {name: 'historyBack', description: 'History Back'}
    {name: 'historyForward', description: 'History Forward'}
    {name: 'gotoParentDirectory', description: 'Goto Parent Directory'}
    {name: 'mark', description: 'Attach Mark'}
    {name: 'jumpToMark', description: 'Jump to Mark'}
]

MODIFIERS = ['Shift', 'Ctrl', 'Alt', 'Command', 'Meta']

app = angular.module('options', ['ngRoute']).
    config ($routeProvider) ->
        $routeProvider
        .when '/',
            redirectTo: '/settings'
        .when '/settings',
            templateUrl: 'settings.html'
            controller: 'settingsCtrl'
        .when '/raw',
            templateUrl: 'raw.html'
            controller: 'rawCtrl'

app.controller 'settingsCtrl', ($scope) ->
    loadSettings = (settings) ->
        convertIntoArray = (options, descriptions) ->
            for description in descriptions
                description: description.description
                name: description.name
                val: _.clone(options[description.name])
                candidates: description.candidates
                isText: not (description.candidates? or (typeof options[description.name] == 'boolean'))
                isSelect: description.candidates?
                isCheckbox: typeof options[description.name] == 'boolean'

        $scope.$apply ->
            $scope.settings = settings
            $scope.configs = convertIntoArray(_.omit(settings, 'bindings'), CONFIG_DESCRIPTIONS)
            $scope.bindings = convertIntoArray(settings['bindings'], BINDING_DESCRIPTIONS)

    chrome.runtime.sendMessage({type: 'getSettings'}, loadSettings)

    onLeaveTab = (cb) ->
        chrome.tabs.getCurrent (tab) ->
            prev_tab_id = null
            chrome.tabs.onActivated.addListener (activeInfo) ->
                if not prev_tab_id? or prev_tab_id == tab.id
                    cb()
                prev_tab_id = activeInfo.tabId

    onRemoveTab = (cb) ->
        window.addEventListener 'beforeunload', ->
            cb()
            return

    leaveTabHandler = ->
        $scope.$broadcast('leaveTab')
            
        $scope.updateSettings()

    $scope.updateSettings = ->
        if not $scope.hasOwnProperty('settings') then return

        convertIntoObject = (options) ->
            obj = {}
            for option in options
                obj[option.name] = option.val
            return obj

        settings = _.extend(convertIntoObject($scope.configs), {bindings: convertIntoObject($scope.bindings)})
        if not _.isEqual($scope.settings, settings)
            chrome.runtime.sendMessage({type: 'setSettings', settings: settings}, loadSettings)
            
    onLeaveTab(leaveTabHandler)
    onRemoveTab(leaveTabHandler)

app.directive 'configs', ->
    restrict: 'E'
    transclude: false
    scope: true
    templateUrl: 'configs.html'
    replace: false

app.directive 'bindings', ->
    restrict: 'E'
    transclude: false
    scope: true
    templateUrl: 'bindings.html'
    replace: false
    controller: ($scope) ->
        $scope.editing = null

        listen = ->
            $scope.listener = hapt.listen( (keys) ->
                $scope.$apply ->
                    {binding: binding, index: index} = $scope.editing
                    binding.val[index] = keys
                    if keys.slice(-1)[0] not in MODIFIERS
                        $scope.finishEditing()
                return false
            , window, true, ['body', 'html', 'button', 'a'])

        $scope.$on 'leaveTab', (event) ->
            $scope.$apply ->
                $scope.finishEditing()

        $scope.finishEditing = ->
            $scope.listener?.stop()
            if not $scope.editing? then return
            {binding: binding, index: index} = $scope.editing
            $scope.editing = null
            if (binding.val[index].every (s) -> s in MODIFIERS)
                binding.val.splice(index, 1)
            else if ( _.range(binding.val.length).some (i) -> i != index and _.isEqual(binding.val[i], binding.val[index]) )
                binding.val.splice(index, 1)
        
        $scope.clickShortcut = (event, binding_index, index) ->
            binding = $scope.bindings[binding_index]
            editing = $scope.editing
            $scope.finishEditing()
            if not _.isEqual({binding: binding, index: index}, editing)
                $scope.editing = {binding: binding, index: index}
                listen()
            return false

        $scope.clickRemove = (event, binding_index, index) ->
            binding = $scope.bindings[binding_index]
            binding.val[index] = []
            $scope.finishEditing()
            return false
            
        $scope.clickAddition = (event, binding_index) ->
            binding = $scope.bindings[binding_index]
            $scope.finishEditing()
            $scope.editing = {binding: binding, index: binding.val.length}
            binding.val.push([])
            listen()
            return false
        
app.controller 'rawCtrl', ($scope) ->
    loadSettings = ->
        chrome.runtime.sendMessage {type: 'getSettings'}, (settings) ->
            $scope.$apply ->
                $scope.settings = settings
                $scope.serializedSettings = JSON.stringify settings, null, 2
    loadSettings()
    $scope.textEmphasis = 'text-warning'
    $scope.textMessage = 'CAUTION: This extension will not work properly if invalid data was input.'

    $scope.save = ->
        try
            settings = JSON.parse $scope.serializedSettings
        catch error
            $scope.textEmphasis = 'text-danger'
            $scope.textMessage = 'ERROR: SyntaxError'
            return
        chrome.runtime.sendMessage {type: 'setSettings', settings: settings}, ->
            $scope.$apply ->
                $scope.textEmphasis = 'text-success'
                $scope.textMessage = 'SUCCESS'
