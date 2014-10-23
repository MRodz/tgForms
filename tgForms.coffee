#############
## tgForms ##
#############

class tgForms
  ### Private constants ###

  repSearch = new RegExp("<span class=\"label\">(.*)<\/span>")
  repReplace = "<span class=\"label\">$1<\/span><span class=\"repeat\">" +
               "[Add One More]</span>"


  ### Private attributes ###

  parser = N3.Parser()

  store = N3.Store()
  storePrefixes = {}

  templates = {}

  util = N3.Util


  ### Private methods ###

  # addToJSONLD

  addToJSONLD = (jsonld, domObject) ->
    key = domObject.closest("div.form-group").attr("class").replace(/.* /, "")
    oldValue = jsonld[key]

    if domObject.val()
      newValue = domObject.val()
    else
      newValue = domObject.text()

    if oldValue? and typeof(oldValue) is "object" and newValue
      jsonld[key].push(newValue)
    else if oldValue? and typeof(oldValue) is "string" and newValue
      jsonld[key] = [oldValue, newValue]
    else if newValue
      jsonld[key] = newValue

    return jsonld

  # prefixCall

  prefixCall = (prefix, uri) ->
    store.addPrefix(prefix, uri)
    storePrefixes[prefix] = uri

  # replacePrefixes

  replacePrefixes = (string) ->
    for prefix, uri of storePrefixes
      string = string.replace(uri, prefix + ":")

    return string

  # sortFields

  sortFields = (a, b) ->
    if a["tgforms:hasPriority"] > b["tgforms:hasPriority"]
      return -1
    else if a["tgforms:hasPriority"] < b["tgforms:hasPriority"]
      return 1

    return 0


  ### Public methods ###

  # addTurtle

  addTurtle: (turtle, addCall) ->
    tripleCall = (error, triple, prefixes) ->
      if triple
        store.addTriple(triple)
      else
        addCall()

    parser.parse(turtle, tripleCall, prefixCall)

  # buildForm

  buildForm: (subject, selector) ->
    form = []
    formHTML = "<form role=\"form\" class=\"tgForms\">"

    formTriples = store.find(null, "tgforms:belongsToForm", subject)

    for formTriple in formTriples
      field = {}

      propTriples = store.find(formTriple.subject, null, null)
      field["rdf:Property"] = replacePrefixes(propTriples[0].subject)
      field["tgforms:hasOption"] = []

      for propTriple in propTriples
        key = propTriple.predicate
        key = replacePrefixes(key)

        value = propTriple.object
        value = util.getLiteralValue(value) if util.isLiteral(value)
        value = replacePrefixes(value)

        if key is "tgforms:hasOption"
          field["tgforms:hasOption"].push(value)
        else
          field[key] = value

      field["tgforms:hasOption"] = field["tgforms:hasOption"].sort()
      field["tgforms:hasPriority"] = parseInt(field["tgforms:hasPriority"])
      field["tgforms:isRepeatable"] = field["tgforms:isRepeatable"] is "true"

      form.push(field)

    form = form.sort(sortFields)

    for field in form
      template = templates[field["tgforms:hasInput"]]
      fieldHTML = Mustache.render(template, field)

      if field["tgforms:isRepeatable"]
        fieldHTML = fieldHTML.replace(repSearch, repReplace)

      formHTML += fieldHTML

    formHTML += "</form>"
    $(selector).html(formHTML)

  # getInput

  getInput: (subject, selector) ->
    jsonld = {
      "@context": storePrefixes,
      "@id": subject
    }

    $(selector + " input").each ->
      $this = $(this)
      jsonld = addToJSONLD(jsonld, $this)

    $(selector + " span.value").each ->
      $this = $(this)
      jsonld = addToJSONLD(jsonld, $this)

    return jsonld

  # fillForm

  fillForm: (subject, selector) ->
    formTriples = store.find(subject, null, null)

    for formTriple in formTriples
      predicate = formTriple.predicate
      predicate = replacePrefixes(predicate)
      predicate = predicate.replace(":", "\\:")

      object = util.getLiteralValue(formTriple.object)

      $this = $(selector + " div." + predicate + " input").last()

      if not $this.val()
        $this.val(object)
      else
        field = $this.closest("div.form-group").clone()
        field.children().find("input").val(object)
        $this.closest("div.form-group").after(field)

      $this = $(selector + " div." + predicate + " span.value").last()

      if not $this.text()
        $this.text(object)
      else
        field = $this.closest("div.form-group").clone()
        field.children().find("span.value").text(object)
        $this.closest("div.form-group").after(field)


#################
## Interaction ##
#################

$(document).on("click", "span.repeat", ->
  $this = $(this)

  field = $this.closest("div.form-group").clone()
  # field.children().find("input").val("")
  # field.children().find("span.value").text("")
  $this.closest("div.form-group").after(field)

  focusCall = -> $this.closest("div.form-group").next().find("input").focus()
  setTimeout(focusCall, 25)
)

$(document).on("click", "ul.dropdown-menu li", (e) ->
  e.preventDefault()
  $this = $(this)
  $this.closest("div.form-group").find("span.value").text($this.text())
)
