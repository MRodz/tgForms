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

  addToJSONLD = (jsonLD, domObject) ->
    if domObject.attr("type") is "checkbox"
      if domObject.prop("checked")
        newValue = true
      else
        return jsonLD

    if domObject.attr("type") is "text"
      if domObject.val()
        newValue = domObject.val()
      else
        return jsonLD

    if domObject.prop("tagName") is "SPAN"
      if domObject.text()
        newValue = domObject.text()
      else
        return jsonLD

    if domObject.prop("tagName") is "TEXTAREA"
      if domObject.val()
        newValue = domObject.val()
      else
        return jsonLD

    classes = domObject.closest("div.form-group").attr("class").split(" ")

    for str in classes
      key = str if str.indexOf(":") > -1 and str.indexOf("tgforms") is -1

    if store.find(key, "rdfs:range", "rdfs:Resource")[0]
      newValue = {"@id": newValue}

    oldValue = jsonLD[key]

    if oldValue instanceof Array
      jsonLD[key].push(newValue)
    else if oldValue
      jsonLD[key] = [oldValue, newValue]
    else
      jsonLD[key] = newValue

    return jsonLD

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

    if a["tgforms:hasPriority"] < b["tgforms:hasPriority"]
      return 1

    return 0

  # expand a Prefix

  expandPrefix = (term) ->
    # function name will be util.expandPrefixedName in later version of n3.js
    return util.expandQName(term, store._prefixes)

  # findFormTriples

  findFormTriples = (subject) ->
    formTriples = []
    triples = store.find(null, null, subject)
    for triple in triples
      if triple.predicate is expandPrefix("rdfs:domain")
        formTriples.push triple
      else if triple.predicate is expandPrefix("rdf:first")
         # we expect a statement like "rdfs:domain [ a owl:Class; owl:unionOf (bol:thing bol:person) ]" here
         # and want to find its domain
         t2 = findListStart(triple.subject)
         # replace blank with subject of this search
         t2.object = expandPrefix(subject)
         formTriples.push t2

    return formTriples

  # findListStart
  # get the starter of a list from n3store

  findListStart = (subject) ->
    triple = store.find(null, null, subject)
    if util.isBlank(triple[0].subject)
      findListStart(triple[0].subject)
    else
      return triple[0]


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

    formTriples = findFormTriples(subject)

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

  # getFormURI

  getFormURI: (subject) ->
    type = store.find(subject, "rdf:type", null)[0].object

    form = store.find(null, "tgforms:represents", type)[0].subject
    form = util.getLiteralValue(form) if util.isLiteral(form)
    form = replacePrefixes(form)

  # getInput

  getInput: (subject, type, selector) ->
    jsonLD = {
      "@context": storePrefixes,
      "@id": subject,
      "@type": type
    }

    $(selector + " input").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    $(selector + " span.value").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    $(selector + " textarea").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    return jsonLD

  # getPrefixes

  getPrefixes: () ->
    return storePrefixes

  # getTypeURI

  getTypeURI: (subject) ->
    type = store.find(subject, "rdf:type", null)[0].object
    type = util.getLiteralValue(type) if util.isLiteral(type)
    type = replacePrefixes(type)

  # fillForm

  fillForm: (subject, selector) ->
    triples = store.find(subject, null, null)

    for triple in triples
      predicate = triple.predicate
      predicate = replacePrefixes(predicate)
      predicate = predicate.replace(":", "\\:")

      object = triple.object
      object = util.getLiteralValue(object) if util.isLiteral(object)
      object = replacePrefixes(object)

      $this = $(selector + " div." + predicate).last()

      if $this.find("input").attr("type") is "checkbox"
        $this.find("input").prop("checked", true) if object is "true"

      if $this.find("input").attr("type") is "text"
        if $this.find("input").val()
          field = $this.closest("div.form-group").clone()
          field.children().find("input").val(object)
          $this.closest("div.form-group").after(field)
        else
          $this.find("input").val(object)

      if $this.find("span.value")
        if $this.find("span.value").text()
          field = $this.closest("div.form-group").clone()
          field.children().find("span.value").text(object)
          $this.closest("div.form-group").after(field)
        else
        $this.find("span.value").text(object)

      if $this.find("textarea")
        if $this.find("textarea").val()
          field = $this.closest("div.form-group").clone()
          field.children().find("textarea").val(object)
          $this.closest("div.form-group").after(field)
        else
          $this.find("textarea").val(object)

  # getStore (for debug purposes)

  getStore: ->
    return store

#################
## Interaction ##
#################

$(document).on("click", "span.repeat", ->
  $this = $(this)

  field = $this.closest("div.form-group").clone()
  field.children().find("input").val("")
  field.children().find("span.value").text("")
  $this.closest("div.form-group").after(field)

  focusCall = -> $this.closest("div.form-group").next().find("input").focus()
  setTimeout(focusCall, 25)
)

$(document).on("click", "ul.dropdown-menu li", (e) ->
  e.preventDefault()
  $this = $(this)
  $this.closest("div.form-group").find("span.value").text($this.text())
)
