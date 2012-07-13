{View} = require 'space-pen'
CommandInterpreter = require 'command-panel/command-interpreter'
RegexAddress = require 'command-panel/commands/regex-address'
CompositeCommand = require 'command-panel/commands/composite-command'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser

_ = require 'underscore'

module.exports =
class CommandPanel extends View
  @activate: (rootView, state) ->
    requireStylesheet 'command-panel.css'
    if state?
      @instance = CommandPanel.deserialize(state, rootView)
    else
      @instance = new CommandPanel(rootView)

  @serialize: ->
    text: @instance.miniEditor.getText()
    visible: @instance.hasParent()

  @deserialize: (state, rootView) ->
    commandPanel = new CommandPanel(rootView)
    commandPanel.attach(state.text) if state.visible
    commandPanel

  @content: ->
    @div class: 'command-panel', =>
      @div ':', class: 'prompt', outlet: 'prompt'
      @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0

  initialize: (@rootView)->
    @commandInterpreter = new CommandInterpreter(@rootView.project)
    @history = []

    @rootView.on 'command-panel:toggle', => @toggle()
    @rootView.on 'command-panel:execute', => @execute()
    @rootView.on 'command-panel:find-in-file', => @attach("/")
    @rootView.on 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    @rootView.on 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddressInReverse()
    @rootView.on 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @miniEditor.off 'move-up move-down'
    @miniEditor.on 'move-up', => @navigateBackwardInHistory()
    @miniEditor.on 'move-down', => @navigateForwardInHistory()

  toggle: ->
    if @parent().length then @detach() else @attach()

  attach: (text='') ->
    @rootView.append(this)
    @miniEditor.focus()
    @miniEditor.setText(text)
    @prompt.css 'font', @miniEditor.css('font')

  detach: ->
    @rootView.focus()
    super

  execute: (command = @miniEditor.getText()) ->
    try
      @commandInterpreter.eval(command, @rootView.getActiveEditSession())
    catch error
      if error instanceof SyntaxError
        @flashError()
        return
      else
        throw error

    @history.push(command)
    @historyIndex = @history.length
    @detach()

  navigateBackwardInHistory: ->
    return if @historyIndex == 0
    @historyIndex--
    @miniEditor.setText(@history[@historyIndex])

  navigateForwardInHistory: ->
    return if @historyIndex == @history.length
    @historyIndex++
    @miniEditor.setText(@history[@historyIndex] or '')

  repeatRelativeAddress: ->
    @commandInterpreter.repeatRelativeAddress(@rootView.getActiveEditSession())

  repeatRelativeAddressInReverse: ->
    @commandInterpreter.repeatRelativeAddressInReverse(@rootView.getActiveEditSession())

  setSelectionAsLastRelativeAddress: ->
    selection = @rootView.getActiveEditor().getSelectedText()
    regex = _.escapeRegExp(selection)
    @commandInterpreter.lastRelativeAddress = new CompositeCommand([new RegexAddress(regex)])
