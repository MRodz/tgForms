#############
## tgForms ##
#############

class tgForms
  ### Private constants ###

  resSearch = new RegExp("<span class=\"label\">(.*)<\/span>")
  resReplace = "<span class=\"label\">$1<\/span><span class=\"resource " +
               "glyphicon glyphicon-link icon-link\" aria-hidden=\"true\"></span>"

  repSearch = new RegExp("<span class=\"label\">(.*)<\/span>")
  repReplace = "<span class=\"label\">$1<\/span><span class=\"repeat " +
               "glyphicon glyphicon-plus icon-plus\" aria-hidden=\"true\"></span>"


  ### Private attributes ###

  parser = N3.Parser()
  store = N3.Store()
  util = N3.Util

  templates = {}


  ### Private methods ###

  # abbrevURI

  abbrevURI = (string) ->
    for prefix, uri of getPrefixes()
      string = string.replace(uri, prefix + ":")

    return string

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

    for string in classes
      if string.indexOf(":") > -1 and string.indexOf("tgforms") is -1
        key = string

    if isResource(key)
      newValue = {"@id": newValue}

    oldValue = jsonLD[key]

    if oldValue instanceof Array
      jsonLD[key].push(newValue)
    else if oldValue
      jsonLD[key] = [oldValue, newValue]
    else
      jsonLD[key] = newValue

    return jsonLD

  # expandPrefix

  expandPrefix = (string) ->
    return util.expandPrefixedName(string, getPrefixes())

  # getClasses

  getClasses = (subject) ->
    rdfClasses = [subject]
    subClassOfTriples = store.find(subject, "rdfs:subClassOf", null)

    for subClassOfTriple in subClassOfTriples
      rdfClass = abbrevURI(subClassOfTriple.object)
      rdfClasses.push(rdfClass)

      for rdfClass in getClasses(rdfClass)
        if rdfClasses.indexOf(rdfClass) is -1
          rdfClasses.push(rdfClass)

    return rdfClasses

  # getFormTriples

  getFormTriples = (subject) ->
    formTriples = []
    rdfClasses = getClasses(subject)

    for rdfClass in rdfClasses
      triples = store.find(null, null, rdfClass)
      for triple in triples
        if triple.predicate is expandPrefix("rdfs:domain")
          formTriples.push(triple)
        else if triple.predicate is expandPrefix("rdf:first")

          # We expect a statement like
          # "rdfs:domain [ a owl:Class; owl:unionOf (bol:thing bol:person) ]"
          # and want to find its domain

          listStart = getListStart(triple.subject)

          # Replace blank node with RDF class

          listStart.object = expandPrefix(rdfClass)

          if listStart.predicate is expandPrefix("rdfs:domain")
            formTriples.push(listStart)

    return formTriples

  # getList

  getList = (subject) ->
    list = []

    firstObject = store.find(subject, "rdf:first", null)[0].object
    restObject = store.find(subject, "rdf:rest", null)[0].object

    list.push(abbrevURI(firstObject))

    if abbrevURI(restObject) isnt "rdf:nil"
      for element in getList(restObject)
        list.push(abbrevURI(element))

    return list

  # getListStart

  getListStart = (object) ->
    triple = store.find(null, null, object)
    if util.isBlank(triple[0].subject)
      getListStart(triple[0].subject)
    else
      return triple[0]

  # getPrefixes

  getPrefixes = () ->
    return store._prefixes

  # getUnionOf

  getUnionOf = (subject, predicate) ->
    mainObject = store.find(subject, predicate, null)[0].object
    unionOfObject = store.find(mainObject, "owl:unionOf", null)[0].object

    return unionOfObject

  # isResource

  isResource = (subject) ->
    rangeObject = store.find(subject, "rdfs:range", null)[0].object
    result = false

    if not abbrevURI(rangeObject).match(/^xsd:/)
      result = true

      if util.isBlank(rangeObject)
        for element in getList(getUnionOf(subject, "rdfs:range"))
          if element.match(/^xsd:/)
            result = result and false

    return result

  # prefixCall

  prefixCall = (prefix, uri) ->
    store.addPrefix(prefix, uri)

  # sortFields

  sortFields = (a, b) ->
    if a["tgforms:hasPriority"] > b["tgforms:hasPriority"]
      return -1

    if a["tgforms:hasPriority"] < b["tgforms:hasPriority"]
      return 1

    return 0

  # getFormField

  getFormField = (subject) ->
    field = {}

    propTriples = store.find(subject, null, null)
    field["rdf:Property"] = abbrevURI(propTriples[0].subject)
    field["tgforms:hasOption"] = []

    for propTriple in propTriples
      key = propTriple.predicate
      key = abbrevURI(key)

      value = propTriple.object

      if util.isLiteral(value)
        value = util.getLiteralValue(value)

      value = abbrevURI(value)

      if key is "tgforms:hasOption"
        field["tgforms:hasOption"].push(value)
      else
        field[key] = value

    if not field["tgforms:hasInput"]
      field["tgforms:hasInput"] = "tgforms:text"

    field["tgforms:hasOption"] = field["tgforms:hasOption"].sort()
    field["tgforms:hasPriority"] = parseInt(field["tgforms:hasPriority"])

    if field["tgforms:isRepeatable"] isnt "false"
      field["tgforms:isRepeatable"] = true
    else
      field["tgforms:isRepeatable"] = false

    return field

  # renderField

  renderField = (field) ->
    template = templates[field["tgforms:hasInput"]]
    fieldHTML = Mustache.render(template, field)

    if isResource(field["rdf:Property"])
      fieldHTML = fieldHTML.replace(resSearch, resReplace)

    if field["tgforms:isRepeatable"]
      fieldHTML = fieldHTML.replace(repSearch, repReplace)

    return fieldHTML

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

    formTriples = getFormTriples(subject)

    for formTriple in formTriples

      field = getFormField(formTriple.subject)
      form.push(field)

    form = form.sort(sortFields)

    for field in form
      formHTML += renderField(field)

    formHTML += "</form>"
    $(selector).html(formHTML)

  # getInput

  getInput: (subject, type, selector) ->
    jsonLD = {
      "@context": getPrefixes(),
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
    return getPrefixes()

  # abbrevURI

  abbrevURI: (string) ->
    abbrevURI(string)

  # getStore

  getStore: ->
    return store

  # getType

  getType: (subject) ->
    type = store.find(subject, "rdf:type", null)[0].object

    if util.isLiteral(type)
      type = util.getLiteralValue(type)

    type = abbrevURI(type)

  # fillForm

  fillForm: (subject, selector) ->
    triples = store.find(subject, null, null)

    for triple in triples
      predicate = triple.predicate
      predicate = abbrevURI(predicate)
      predicate = predicate.replace(":", "\\:")

      object = triple.object

      if util.isLiteral(object)
        object = util.getLiteralValue(object)

      object = abbrevURI(object)

      $this = $(selector + " div." + predicate).last()

      if $this.find("input").attr("type") is "checkbox"
        if object is "true"
          $this.find("input").prop("checked", true)

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

  # getFormField

  getFormField: (subject) ->
    getFormField(subject)

  # renderField

  renderField: (field) ->
    renderField(field)

#################
## Interaction ##
#################

$(document).on("click", "span.repeat", ->
  $this = $(this)

  inputname = $this.closest("div.form-group").attr("data-tgform-name")
  console.log(inputname)
  # TODO: this is not done well, as it assumes the name of the tgForms Object to be tgf
  field = tgf.getFormField(inputname)
  fieldHtml = tgf.renderField(field)

  $this.closest("div.form-group").after(fieldHtml)

  focusCall = -> $this.closest("div.form-group").next().find("input").focus()
  setTimeout(focusCall, 25)
)

$(document).on("click", "ul.dropdown-menu li", (e) ->
  e.preventDefault()
  $this = $(this)
  $this.closest("div.form-group").find("span.value").text($this.text())
)
