#= require trix/elements/trix_toolbar_element
#= require trix/controllers/editor_controller

{makeElement, triggerEvent, handleEvent, handleEventOnce, defer} = Trix
{classNames} = Trix.config.css

Trix.registerElement "trix-editor", do ->
  id = 0

  # Contenteditable support helpers

  makeEditable = (element) ->
    return if element.hasAttribute("contenteditable")
    element.setAttribute("contenteditable", "")
    handleEventOnce("focus", onElement: element, withCallback: -> configureContentEditable(element))

  configureContentEditable = (element) ->
    disableObjectResizing(element)
    setDefaultParagraphSeparator(element)

  disableObjectResizing = (element) ->
    if document.queryCommandSupported?("enableObjectResizing")
      document.execCommand("enableObjectResizing", false, false)
      handleEvent("mscontrolselect", onElement: element, preventDefault: true)

  setDefaultParagraphSeparator = (element) ->
    if document.queryCommandSupported?("DefaultParagraphSeparator")
      {tagName} = Trix.config.blockAttributes.default
      if tagName in ["div", "p"]
        document.execCommand("DefaultParagraphSeparator", false, tagName)

  # Style

  defaultCSS: """
    %t {
      overflow: auto;
    }

    %t:empty:not(:focus)::before {
      content: attr(placeholder);
      color: graytext;
    }

    %t a[contenteditable=false] {
      cursor: text;
    }

    %t img {
      max-width: 100%;
    }

    %t .#{classNames.attachment.captionEditor} {
      resize: none;
    }

    %t .#{classNames.attachment.captionEditor}.trix-autoresize-clone {
      position: absolute;
      left: -9999px;
      max-height: 0px;
    }
  """

  # Properties

  composition:
    get: ->
      @editorController?.composition

  document:
    get: ->
      @composition?.document

  selectedRange:
    get: ->
      @composition?.getSelectedRange()

  trixId:
    get: ->
      if @hasAttribute("trix-id")
        @getAttribute("trix-id")
      else
        @setAttribute("trix-id", ++id)
        @trixId

  toolbarElement:
    get: ->
      if @hasAttribute("toolbar")
        @ownerDocument?.getElementById(@getAttribute("toolbar"))
      else if @parentElement
        toolbarId = "trix-toolbar-#{@trixId}"
        @setAttribute("toolbar", toolbarId)
        element = makeElement("trix-toolbar", id: toolbarId)
        @parentElement.insertBefore(element, this)
        element

  inputElement:
    get: ->
      if @hasAttribute("input")
        @ownerDocument?.getElementById(@getAttribute("input"))
      else if @parentElement
        inputId = "trix-input-#{@trixId}"
        @setAttribute("input", inputId)
        element = makeElement("input", type: "hidden", id: inputId)
        @parentElement.insertBefore(element, @nextElementSibling)
        element

  name:
    get: ->
      @inputElement?.name

  value:
    get: ->
      @inputElement?.value
    set: (@defaultValue) ->
      @editorController?.loadHTML(@defaultValue)

  # Selection methods

  getClientRectAtPosition: (position) ->
    @editorController?.getClientRectAtPosition(position)

  # Controller delegate methods

  notify: (message, data) ->
    switch message
      when "document-change"
        @documentChangedSinceLastRender = true
      when "render"
        if @documentChangedSinceLastRender
          @documentChangedSinceLastRender = false
          @notify("change")
      when "change", "attachment-add", "attachment-edit", "attachment-remove"
        @inputElement?.value = Trix.serializeToContentType(this, "text/html")

    if @editorController
      triggerEvent("trix-#{message}", onElement: this, attributes: data)

  # Element lifecycle

  createdCallback: ->
    makeEditable(this)

  attachedCallback: ->
    @editorController ?= new Trix.EditorController(editorElement: this, html: @defaultValue = @value)
    @editorController.registerSelectionManager()
    @registerResetListener()
    requestAnimationFrame => @notify("initialize")

  detachedCallback: ->
    @editorController?.unregisterSelectionManager()
    @unregisterResetListener()

  # Form reset support

  registerResetListener: ->
    @resetListener = @resetBubbled.bind(this)
    window.addEventListener("reset", @resetListener, false)

  unregisterResetListener: ->
    window.removeEventListener("reset", @resetListener, false)

  resetBubbled: (event) ->
    if event.target is @inputElement?.form
      @reset() unless event.defaultPrevented

  reset: ->
    @value = @defaultValue

  # JSON serialization

  loadJSON: (json) ->
    @editorController?.loadJSON(json)

  toJSON: ->
    @editorController?.toJSON()
